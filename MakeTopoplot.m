%% Topomap_Certainty_Bins.m
% Sensor topographies of the event-related field (ERF) in 100 ms bins for
% CERTAIN trials, UNCERTAIN trials, and their difference (uncertain - certain).
%
% Data selection is identical to GLM_Subspace_Flickering.m /
% Example_Trials_Context_Flicker.m:
%   - stimulus-locked (or cue-locked) preprocessed data, Day 1 + Day 2 appended
%   - trials with trialinfo(:,6) == 1
%   - certain = configuration (trialinfo(:,9)) 1 or 4, uncertain = otherwise
%
% Pipeline:
%   1) per participant: ERF per condition (ft_timelockanalysis)
%   2) grand average across participants (ft_timelockgrandaverage)
%   3) three figures, one topoplot per 100 ms bin (common colour scale for
%      certain and uncertain, separate symmetric scale for the difference)
%   4) optional cluster-based permutation test (uncertain vs certain) over
%      channels x time across the whole plotted window; channels belonging to
%      a significant cluster at any time point within a bin are highlighted on
%      the difference maps
%
% Requires FieldTrip.

clear all
close all

%% Add FieldTrip
addpath('./Toolbox/fieldtrip-20261001')
ft_defaults

%% Parameters
cue_first   = 0;
data_folder = './Preprocessed/';
subjects    = [1:20, 22:28, 30];

channels    = 'all';          % e.g. 'all', 'EEG', {'all','-EOG*'}; for MEG: 'MEG', 'MEGMAG', ...
layout_file = '';             % e.g. 'easycapM1.mat', 'acticap-64ch-standard2.mat';
                              % '' = build from sensor positions in the data (elec or grad)

time_range  = [-3.5 0.5];       % window to plot (s); must lie within [-4 1.5]
bin_width   = 0.15;            % bin size (s)
baseline    = [];             % e.g. [-0.2 0]; [] = no baseline correction

do_stats         = true;      % cluster-based permutation test on the difference
n_randomization  = 1000;
cluster_alpha    = 0.05;
alpha            = 0.025;     % per tail (two-tailed test)

n_cols      = 5;              % topoplots per row
save_figs   = true;
out_folder  = './Figures/Topomaps_Certainty/';
fig_format  = 'svg';          % 'svg', 'png', 'pdf', ...

if save_figs && ~exist(out_folder, 'dir'), mkdir(out_folder); end

%% Bins
bin_edges = time_range(1):bin_width:time_range(2);
bin_edges = round(bin_edges * 1000) / 1000;          % avoid floating-point drift
n_bins    = numel(bin_edges) - 1;

%% Per-participant ERFs
nS     = numel(subjects);
TL_cer = cell(1, nS);
TL_unc = cell(1, nS);
n_trials = zeros(nS, 2);                              % [certain uncertain]

for s = 1:nS
    subj = subjects(s);
    fprintf('Processing subject %d\n', subj);

    if cue_first == 1
        Day1Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day1-CuePreprocessed.mat']));
        Day2Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day2-CuePreprocessed.mat']));
    else
        Day1Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day1-StimPreprocessed.mat']));
        Day2Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day2-StimPreprocessed.mat']));
    end

    cfg  = [];
    data = ft_appenddata(cfg, Day1Res.preprocessed, Day2Res.preprocessed);
    % appenddata can drop sensor positions if they differ between days
    for sf = {'elec', 'grad'}
        if ~isfield(data, sf{1}) && isfield(Day1Res.preprocessed, sf{1})
            data.(sf{1}) = Day1Res.preprocessed.(sf{1});
        end
    end
    % sample numbers overlap across the two days -> drop to avoid warnings
    if isfield(data, 'sampleinfo'), data = rmfield(data, 'sampleinfo'); end

    if s == 1
        sel = ft_channelselection(channels, data.label);
        if isempty(sel)
            error('channels = ''%s'' matches none of the %d channels in the data (e.g. %s).', ...
                char(string(channels)), numel(data.label), strjoin(data.label(1:min(5,end))', ', '));
        end
        fprintf('Using %d channels.\n', numel(sel));
    end

    cfg         = [];
    cfg.latency = [-4 1.5];
    cfg.trials  = find(data.trialinfo(:,6) == 1);
    data        = ft_selectdata(cfg, data);

    certain = data.trialinfo(:,9) == 1 | data.trialinfo(:,9) == 4;
    n_trials(s,:) = [sum(certain) sum(~certain)];

    cfg         = [];
    cfg.channel = channels;
    cfg.latency = time_range;

    cfg.trials = find(certain);
    TL_cer{s}  = ft_timelockanalysis(cfg, data);
    cfg.trials = find(~certain);
    TL_unc{s}  = ft_timelockanalysis(cfg, data);

    if ~isempty(baseline)
        cfgb          = [];
        cfgb.baseline = baseline;
        TL_cer{s} = ft_timelockbaseline(cfgb, TL_cer{s});
        TL_unc{s} = ft_timelockbaseline(cfgb, TL_unc{s});
    end

    if s == 1                                          % sensor positions for layout
        file_layout = find_layout_in_file(Day1Res);
        sens = struct();
        if isfield(data, 'elec'), sens.elec = data.elec; end
        if isfield(data, 'grad'), sens.grad = data.grad; end
    end

    clear data Day1Res Day2Res
end

fprintf('Trials per participant: certain %.0f +/- %.0f, uncertain %.0f +/- %.0f (mean +/- SD)\n', ...
    mean(n_trials(:,1)), std(n_trials(:,1)), mean(n_trials(:,2)), std(n_trials(:,2)));

%% Grand averages and difference
cfg = [];
cfg.keepindividual = 'no';
GA_cer = ft_timelockgrandaverage(cfg, TL_cer{:});
GA_unc = ft_timelockgrandaverage(cfg, TL_unc{:});

cfg = [];
cfg.operation = 'subtract';
cfg.parameter = 'avg';
GA_diff = ft_math(cfg, GA_unc, GA_cer);            % uncertain - certain

%% Layout
cfg = [];
if ~isempty(layout_file)
    cfg.layout = layout_file;
elseif ~isempty(file_layout)
    cfg.layout = file_layout;                          % layout stored in the preprocessed file
    fprintf('Using the layout stored in the preprocessed file.\n');
elseif isfield(sens, 'elec')
    cfg.elec = sens.elec;
elseif isfield(sens, 'grad')
    cfg.grad = sens.grad;
else
    % No sensor positions stored: pick the FieldTrip template whose labels
    % best match the data
    candidates = {'acticap-64ch-standard2.mat', 'easycapM1.mat', 'easycapM11.mat', ...
                  'easycapM10.mat', 'biosemi64.lay', 'EEG1010.lay'};
    best_n = -1;
    for k = 1:numel(candidates)
        try
            lay_k = ft_prepare_layout(struct('layout', candidates{k}));
        catch
            continue                                   % template not available
        end
        n_k = numel(intersect(lower(GA_cer.label), lower(lay_k.label)));
        fprintf('  layout %-28s matches %d/%d channels\n', candidates{k}, n_k, numel(GA_cer.label));
        if n_k > best_n
            best_n = n_k; cfg.layout = candidates{k};
        end
    end
    if best_n <= 0
        error('No template layout matches the channel labels. Set layout_file manually.');
    end
    fprintf('Using layout %s (%d/%d channels matched)\n', cfg.layout, best_n, numel(GA_cer.label));
end
layout = ft_prepare_layout(cfg);

% Match label capitalisation to the layout (e.g. 'FCZ' -> 'FCz') so channels are plotted
[tf, loc] = ismember(lower(GA_cer.label), lower(layout.label));
new_label = GA_cer.label;
new_label(tf) = layout.label(loc(tf));
GA_cer.label = new_label; GA_unc.label = new_label; GA_diff.label = new_label;
for s = 1:nS
    TL_cer{s}.label = new_label; TL_unc{s}.label = new_label;
end

missing = setdiff(GA_cer.label, layout.label);
if ~isempty(missing)
    warning('%d channels not in the layout and will not be plotted: %s', ...
        numel(missing), strjoin(missing', ', '));
end

%% Cluster-based permutation test (channels x time)
sig_chan = cell(1, n_bins);                         % labels to highlight per bin
stat = [];
if do_stats
    cfg = [];
    cfg.method   = 'triangulation';
    cfg.layout   = layout;
    cfg.channel  = intersect(GA_cer.label, layout.label);
    neighbours   = ft_prepare_neighbours(cfg);

    cfg = [];
    cfg.channel          = intersect(GA_cer.label, layout.label);
    cfg.latency          = time_range;
    cfg.method           = 'montecarlo';
    cfg.statistic        = 'ft_statfun_depsamplesT';
    cfg.correctm         = 'cluster';
    cfg.clusteralpha     = cluster_alpha;
    cfg.clusterstatistic = 'maxsum';
    cfg.minnbchan        = 2;
    cfg.neighbours       = neighbours;
    cfg.tail             = 0;
    cfg.clustertail      = 0;
    cfg.alpha            = alpha;
    cfg.numrandomization = n_randomization;
    cfg.design           = [1:nS 1:nS; ones(1,nS) 2*ones(1,nS)];
    cfg.uvar             = 1;
    cfg.ivar             = 2;
    stat = ft_timelockstatistics(cfg, TL_unc{:}, TL_cer{:});   % positive t = uncertain > certain

    % report clusters
    report_clusters(stat, 'pos', alpha);
    report_clusters(stat, 'neg', alpha);

    % channels in a significant cluster at any time within each bin
    for b = 1:n_bins
        t_in = stat.time >= bin_edges(b) & stat.time < bin_edges(b+1);
        sig_chan{b} = stat.label(any(stat.mask(:, t_in), 2));
    end
end

%% Colour limits
amax_cond = max(abs([GA_cer.avg(:); GA_unc.avg(:)]));
amax_diff = max(abs(GA_diff.avg(:)));
cmap      = diverging_cmap(256);

%% Figures
make_topo_figure(GA_cer,  bin_edges, n_cols, layout, [-amax_cond amax_cond], cmap, {}, ...
    'Certain', 'ERF amplitude');
if save_figs, save_figure(gcf, fullfile(out_folder, 'topo_certain'), fig_format); end

make_topo_figure(GA_unc,  bin_edges, n_cols, layout, [-amax_cond amax_cond], cmap, {}, ...
    'Uncertain', 'ERF amplitude');
if save_figs, save_figure(gcf, fullfile(out_folder, 'topo_uncertain'), fig_format); end

ttl = 'Uncertain - certain';
if do_stats, ttl = [ttl ' (highlighted: channels in significant cluster)']; end
make_topo_figure(GA_diff, bin_edges, n_cols, layout, [-amax_diff amax_diff], cmap, sig_chan, ...
    ttl, '\Delta ERF amplitude');
if save_figs, save_figure(gcf, fullfile(out_folder, 'topo_difference'), fig_format); end

if save_figs && do_stats
    save(fullfile(out_folder, 'cluster_stat.mat'), 'stat');
end

%% =============================
%% Local functions
%% =============================
function make_topo_figure(GA, bin_edges, n_cols, layout, zlim, cmap, sig_chan, ttl, cblabel)
n_bins = numel(bin_edges) - 1;
n_rows = ceil(n_bins / n_cols);
figure('Color','w', 'Position', [50 50 230*n_cols 220*n_rows + 60]);

for b = 1:n_bins
    subplot(n_rows, n_cols, b);
    cfg = [];
    cfg.figure    = 'gca';
    cfg.layout    = layout;
    cfg.parameter = 'avg';
    cfg.xlim      = bin_edges([b b+1]);
    cfg.zlim      = zlim;
    cfg.colormap  = cmap;
    cfg.marker    = 'off';
    cfg.comment   = 'no';
    cfg.interactive = 'no';
    if ~isempty(sig_chan) && ~isempty(sig_chan{b})
        cfg.highlight          = 'on';
        cfg.highlightchannel   = sig_chan{b};
        cfg.highlightsymbol    = '.';
        cfg.highlightsize      = 12;
        cfg.highlightcolor     = [0 0 0];
    end
    ft_topoplotER(cfg, GA);
    title(sprintf('%d to %d ms', round(1000*bin_edges(b)), round(1000*bin_edges(b+1))), ...
        'FontWeight', 'normal');
end

colormap(cmap);
cb_ax = axes('Position', [0.93 0.25 0.01 0.5], 'Visible', 'off');
caxis(cb_ax, zlim); colormap(cb_ax, cmap);
cb = colorbar(cb_ax, 'Position', [0.93 0.25 0.012 0.5]);
cb.Label.String = cblabel;

sgtitle(ttl)
end

function lay = find_layout_in_file(S)
% Look for a FieldTrip layout among the variables loaded from the .mat file:
% either a variable named like 'layout'/'lay', or any struct with pos + label.
lay = [];
fn  = fieldnames(S);
is_layout = @(x) isstruct(x) && isfield(x, 'pos') && isfield(x, 'label');
% 1) top-level variables
for k = 1:numel(fn)
    v = S.(fn{k});
    if is_layout(v) || (ischar(v) && contains(lower(fn{k}), 'lay'))   % struct or template name
        lay = v; fprintf('Found layout variable "%s".\n', fn{k}); return;
    end
end
% 2) layout stored inside a top-level struct (e.g. preprocessed.layout / cfg.layout)
for k = 1:numel(fn)
    v = S.(fn{k});
    if ~isstruct(v), continue; end
    for sub = {'layout', 'lay'}
        if isfield(v, sub{1}) && is_layout(v.(sub{1}))
            lay = v.(sub{1}); fprintf('Found layout in "%s.%s".\n', fn{k}, sub{1}); return;
        end
    end
    if isfield(v, 'cfg') && isfield(v.cfg, 'layout') && ...
            (is_layout(v.cfg.layout) || ischar(v.cfg.layout))   % struct or template name
        lay = v.cfg.layout; fprintf('Found layout in "%s.cfg.layout".\n', fn{k}); return;
    end
end
end

function report_clusters(stat, which, alpha)
fld = [which 'clusters'];
lab = [which 'clusterslabelmat'];
if ~isfield(stat, fld) || isempty(stat.(fld))
    fprintf('No %s clusters.\n', which);
    return
end
for c = 1:numel(stat.(fld))
    p = stat.(fld)(c).prob;
    if p > 0.5, break; end
    [ch, tt] = find(stat.(lab) == c);
    fprintf('%s cluster %d: p = %.4f%s, %d channels, %d to %d ms\n', ...
        which, c, p, repmat(' *', 1, p < alpha), numel(unique(ch)), ...
        round(1000*stat.time(min(tt))), round(1000*stat.time(max(tt))));
end
end

function cmap = diverging_cmap(n)
% blue - white - red
half = floor(n/2);
b = [linspace(0.13,1,half)' linspace(0.40,1,half)' linspace(0.67,1,half)'];
r = [linspace(1,0.70,n-half)' linspace(1,0.09,n-half)' linspace(1,0.17,n-half)'];
cmap = [b; r];
end

function save_figure(fig, fname_noext, fmt)
fname = [fname_noext '.' fmt];
if strcmpi(fmt, 'svg')
    set(fig, 'Renderer', 'painters');
    print(fig, fname, '-dsvg');
else
    exportgraphics(fig, fname, 'Resolution', 200);
end
end
