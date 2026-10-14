%% Spectral_IRASA_Context.m
% Power and amplitude spectra of the context-axis trajectory (certain vs
% uncertain), as in Example_Trials_Context_Flicker.m, plus a 1/f correction
% with IRASA (Irregular-Resampling Auto-Spectral Analysis; Wen & Liu, 2016).
%
% Signal: single-trial projection of the EEG onto the GLM context axis
% (same GLM as GLM_Subspace_Flickering.m), -3 to -0.1 s, demeaned and scaled
% to unit SD per trial (so spectra reflect spectral shape, not total power).
%
% IMPORTANT: by default the spectra are computed on the UNSMOOTHED projection.
% The moving-average smoothing used for flicker counting is a low-pass filter
% with spectral zeros; it would distort the spectrum and violate IRASA's
% power-law assumption  for the aperiodic component. Set
% smooth_for_spectra = true to reproduce the spectra of the earlier script.
%
% Per participant and condition (FieldTrip):
%   - mtmfft (Hanning), per trial -> power (mean of |X|^2) and amplitude (mean of |X|)
%   - IRASA -> 'original' and 'fractal' (aperiodic) power, averaged over trials
%   - oscillatory power = original - fractal (a.u.) and 10*log10(original/fractal) (dB)
%   - aperiodic exponent and offset: line fit to log10(fractal) vs log10(f)
%
% Figures:
%   1/2  power:      conditions | difference (cluster tests)   + band bars
%   3/4  amplitude:  conditions | difference (cluster tests)   + band bars
%   5    1/f decomposition per condition: original vs aperiodic, oscillatory
%        spectrum, oscillatory band bars, aperiodic exponent/offset, aperiodic difference
%   6    1/f-corrected difference: oscillatory difference spectra with cluster
%        tests + oscillatory band difference bars
%
% Requires FieldTrip (recent version, ft_freqanalysis with method 'irasa')
% and the Statistics and Machine Learning Toolbox.

clear all
close all

%% Add FieldTrip
restoredefaultpath      % remove any other FieldTrip version from the path
addpath('./Toolbox/fieldtrip-20261001')
ft_defaults

%% Parameters
cue_first   = 0;
data_folder = './Preprocessed/';
subjects    = [1:20, 22:28, 30];

toi          = [0.1, 0.4];   % window for GLM betas (s)
toi2         = [-3.5, -3.1];   % window for spectra (s), as in the flicker analysis
axis_id      = 2;            % 1 = "motor" (outcome) axis, 2 = context axis
axis_names   = {'Motor axis', 'Context axis'};

smooth_for_spectra = false;  % true = use the moving-average-smoothed trajectory
window_size  = 20;           % smoothing window (samples), only if smoothing

foi          = [1 20];       % frequency range (Hz)
pad_sec      = 4;            % zero-pad trials to 4 s -> 0.25 Hz frequency grid
fit_range    = [2 20];       % aperiodic fit range (Hz); avoid the lowest bins

bands        = [4 6; 7 9; 10 12];
band_scale   = 'dB';         % 'dB' or 'linear' for band values and tests

n_perm        = 10000;       % sign-flip permutations for cluster tests
cluster_alpha = 0.05;
alpha         = 0.05;

save_figs    = true;
out_folder   = './Figures/Spectra_IRASA_Context/';
fig_format   = 'svg';

if save_figs && ~exist(out_folder, 'dir'), mkdir(out_folder); end
rng(1)

col_cer = [0.2 0.6 0.8];
col_unc = [0.8 0.4 0.4];

freq_grid = foi(1):1/pad_sec:foi(2);
nF = numel(freq_grid);

%% Storage (participants x frequencies; exponents participants x [certain uncertain])
nS = numel(subjects);
flds = {'pow_cer','pow_unc','amp_cer','amp_unc','orig_cer','orig_unc','frac_cer','frac_unc'};
for k = 1:numel(flds), G.(flds{k}) = nan(nS, nF); end
G.exponent = nan(nS, 2);
G.offset   = nan(nS, 2);
G.n_trials = nan(nS, 2);

%% Loop over subjects
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
    if isfield(data, 'sampleinfo'), data = rmfield(data, 'sampleinfo'); end

    cfg         = [];
    cfg.latency = [-4 1.5];
    cfg.trials  = find(data.trialinfo(:,6) == 1);
    data        = ft_selectdata(cfg, data);

    time_vec = data.time{1};
    fs       = 1 / mean(diff(time_vec));
    nTrials  = numel(data.trial);

    X3 = permute(cat(3, data.trial{:}), [3 1 2]);     % trials x channels x time

    %% Regressors (same coding as before)
    cue     = data.trialinfo(:,3); cue(cue == 2) = -1;
    outcome = data.trialinfo(:,8); outcome(outcome == 0) = -1;   % NB: column 8 = Outcome
    certain = ismember(data.trialinfo(:,9), [1 4]);
    clear data Day1Res Day2Res

    %% GLM axis
    Xd       = [outcome cue ones(nTrials,1)];
    time_idx = time_vec > toi(1) & time_vec < toi(2);
    Yavg     = zscore(squeeze(mean(X3(:,:,time_idx), 3)), 0, 1);
    betas    = (Xd' * Xd) \ (Xd' * Yavg);
    w        = betas(axis_id, :)';                     % channels x 1

    %% Projection in the spectral window
    if smooth_for_spectra
        X3 = movmean(X3, window_size, 3);
    end
    t_ix = time_vec > toi2(1) & time_vec < toi2(2);
    tvec = time_vec(t_ix);
    Xw   = X3(:,:,t_ix);
    clear X3
    z = zeros(nTrials, numel(tvec));
    for tr = 1:nTrials
        z(tr,:) = w' * squeeze(Xw(tr,:,:));
    end
    clear Xw
    z = (z - mean(z, 2)) ./ std(z, 0, 2);              % unit SD per trial

    % FieldTrip raw structure with one "channel" = the trajectory
    ftd         = [];
    ftd.label   = {'traj'};
    ftd.fsample = fs;
    ftd.trial   = arrayfun(@(i) z(i,:), 1:nTrials, 'UniformOutput', false);
    ftd.time    = repmat({tvec}, 1, nTrials);

    %% Spectra per condition
    conds = {find(certain), find(~certain)};
    tags  = {'cer', 'unc'};
    for c = 1:2
        G.n_trials(s,c) = numel(conds{c});

        % single-trial power -> mean power and mean amplitude
        cfg            = [];
        cfg.method     = 'mtmfft';
        cfg.taper      = 'hanning';
        cfg.output     = 'pow';
        cfg.foilim     = foi;
        cfg.pad        = pad_sec;
        cfg.keeptrials = 'yes';
        cfg.trials     = conds{c};
        cfg.feedback   = 'no';
        F  = ft_freqanalysis(cfg, ftd);
        Ptr = reshape(F.powspctrm, size(F.powspctrm,1), []);   % trials x freq
        G.(['pow_' tags{c}])(s,:) = interp1(F.freq, mean(Ptr, 1),       freq_grid);
        G.(['amp_' tags{c}])(s,:) = interp1(F.freq, mean(sqrt(Ptr), 1), freq_grid);

        % IRASA: aperiodic ('fractal') and matched 'original' power
        cfg            = [];
        cfg.method     = 'irasa';
        cfg.foilim     = foi;
        cfg.pad        = pad_sec;
        cfg.keeptrials = 'no';
        cfg.trials     = conds{c};
        cfg.feedback   = 'no';
        cfg.output     = 'fractal';
        Ffr = ft_freqanalysis(cfg, ftd);
        cfg.output     = 'original';
        For = ft_freqanalysis(cfg, ftd);
        G.(['frac_' tags{c}])(s,:) = interp1(Ffr.freq, Ffr.powspctrm(1,:), freq_grid);
        G.(['orig_' tags{c}])(s,:) = interp1(For.freq, For.powspctrm(1,:), freq_grid);

        % aperiodic exponent and offset (log-log line fit)
        fi = freq_grid >= fit_range(1) & freq_grid <= fit_range(2);
        pf = polyfit(log10(freq_grid(fi)), log10(G.(['frac_' tags{c}])(s,fi)), 1);
        G.exponent(s,c) = -pf(1);
        G.offset(s,c)   =  pf(2);
    end
end

%% Derived quantities
G.osc_cer_abs = G.orig_cer - G.frac_cer;                 % oscillatory power (a.u.)
G.osc_unc_abs = G.orig_unc - G.frac_unc;
G.osc_cer_db  = 10*log10(G.orig_cer ./ G.frac_cer);      % dB above aperiodic
G.osc_unc_db  = 10*log10(G.orig_unc ./ G.frac_unc);

sem = @(x) std(x, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(x), 1));
ttl_base = sprintf('%s trajectory (N = %d%s)', axis_names{axis_id}, nS, ...
    ternary(smooth_for_spectra, ', smoothed', ''));

%% =============================
%% FIGURES 1-2: power (uncorrected)
%% =============================
spectrum_figures(freq_grid, G.pow_cer, G.pow_unc, 10, 'power', bands, band_scale, ...
    col_cer, col_unc, n_perm, cluster_alpha, alpha, sem, ttl_base, ...
    save_figs, out_folder, fig_format);

%% =============================
%% FIGURES 3-4: amplitude (uncorrected)
%% =============================
spectrum_figures(freq_grid, G.amp_cer, G.amp_unc, 20, 'amplitude', bands, band_scale, ...
    col_cer, col_unc, n_perm, cluster_alpha, alpha, sem, ttl_base, ...
    save_figs, out_folder, fig_format);

%% =============================
%% FIGURE 5: 1/f decomposition per condition
%% =============================
if strcmpi(band_scale, 'dB')
    osc_cer = G.osc_cer_db; osc_unc = G.osc_unc_db;
    osc_label = 'Oscillatory power (dB above aperiodic)';
else
    osc_cer = G.osc_cer_abs; osc_unc = G.osc_unc_abs;
    osc_label = 'Oscillatory power (a.u.)';
end
nB = size(bands,1);
bo_cer = zeros(nS, nB); bo_unc = zeros(nS, nB);
for b = 1:nB
    fi = freq_grid >= bands(b,1) & freq_grid <= bands(b,2);
    bo_cer(:,b) = mean(osc_cer(:,fi), 2);
    bo_unc(:,b) = mean(osc_unc(:,fi), 2);
end

fig5 = figure('Color','w','Position',[100 100 1350 800]);

% (a) original vs aperiodic, log-log
subplot(2,3,1); hold on
h = gobjects(4,1);
h(1) = plot(freq_grid, mean(G.orig_cer,1), '-',  'Color', col_cer, 'LineWidth', 2);
h(2) = plot(freq_grid, mean(G.frac_cer,1), '--', 'Color', col_cer, 'LineWidth', 2);
h(3) = plot(freq_grid, mean(G.orig_unc,1), '-',  'Color', col_unc, 'LineWidth', 2);
h(4) = plot(freq_grid, mean(G.frac_unc,1), '--', 'Color', col_unc, 'LineWidth', 2);
set(gca, 'XScale', 'log', 'YScale', 'log'); xlim(foi)
xline(fit_range(1), 'k:');
xlabel('Frequency (Hz)'); ylabel('Power (a.u.)'); box on
legend(h, {'Certain original','Certain aperiodic','Uncertain original','Uncertain aperiodic'}, ...
    'Location', 'southwest')
title(sprintf('IRASA decomposition (fit %g-%g Hz)', fit_range), 'FontWeight', 'normal')

% (b) oscillatory spectrum per condition
subplot(2,3,2); hold on
cond_spectrum_panel(freq_grid, osc_cer, osc_unc, col_cer, col_unc, bands, sem, ...
    osc_label, 'Oscillatory (1/f-corrected) spectrum');
yline(0, 'k:');

% (c) oscillatory band bars per condition
subplot(2,3,3); hold on
cond_bar_panel(bo_cer, bo_unc, bands, ['Band ' lower(osc_label)], col_cer, col_unc);
print_paired_bands('Oscillatory band power, uncertain vs certain', bo_cer, bo_unc, bands);

% (d) aperiodic exponent
subplot(2,3,4); hold on
paired_distribution(G.exponent(:,1), G.exponent(:,2), col_cer, col_unc);
[~, p, ~, st] = ttest(G.exponent(:,2), G.exponent(:,1));
ylabel('Aperiodic exponent'); title(sprintf('Exponent: t(%d) = %.2f, p = %.3g', st.df, st.tstat, p), 'FontWeight','normal')
fprintf('\nAperiodic exponent, uncertain vs certain: t(%d) = %.2f, p = %.4f\n', st.df, st.tstat, p);

% (e) aperiodic offset
subplot(2,3,5); hold on
paired_distribution(G.offset(:,1), G.offset(:,2), col_cer, col_unc);
[~, p, ~, st] = ttest(G.offset(:,2), G.offset(:,1));
ylabel('Aperiodic offset (log_{10} power)'); title(sprintf('Offset: t(%d) = %.2f, p = %.3g', st.df, st.tstat, p), 'FontWeight','normal')
fprintf('Aperiodic offset, uncertain vs certain: t(%d) = %.2f, p = %.4f\n', st.df, st.tstat, p);

% (f) aperiodic difference spectrum
subplot(2,3,6); hold on
dfrac = 10*log10(G.frac_unc) - 10*log10(G.frac_cer);
rng(3); CLf = cluster_perm_paired(dfrac, n_perm, cluster_alpha);
diff_spectrum_panel(freq_grid, dfrac, CLf, bands, alpha, sem, '\Delta aperiodic power (dB)');
title_with_clusters('Aperiodic: uncertain - certain', CLf, freq_grid, alpha);
report_clusters_freq('Aperiodic power (dB)', CLf, freq_grid, alpha);

sgtitle(['1/f decomposition (IRASA), ' ttl_base])
if save_figs, save_figure(fig5, fullfile(out_folder, 'irasa_conditions'), fig_format); end

%% =============================
%% FIGURE 6: 1/f-corrected difference
%% =============================
d_osc_db  = G.osc_unc_db  - G.osc_cer_db;
d_osc_abs = G.osc_unc_abs - G.osc_cer_abs;
rng(4); CL_db  = cluster_perm_paired(d_osc_db,  n_perm, cluster_alpha);
rng(5); CL_abs = cluster_perm_paired(d_osc_abs, n_perm, cluster_alpha);

fig6 = figure('Color','w','Position',[100 100 1300 420]);

subplot(1,3,1); hold on
diff_spectrum_panel(freq_grid, d_osc_abs, CL_abs, bands, alpha, sem, '\Delta oscillatory power (a.u.)');
title_with_clusters('Oscillatory power: uncertain - certain', CL_abs, freq_grid, alpha);

subplot(1,3,2); hold on
diff_spectrum_panel(freq_grid, d_osc_db, CL_db, bands, alpha, sem, '\Delta oscillatory power (dB)');
title_with_clusters('Oscillatory power (dB): uncertain - certain', CL_db, freq_grid, alpha);

subplot(1,3,3); hold on
band_bar_panel(bo_unc - bo_cer, bands, ['\Delta band ' lower(osc_label)], [0.45 0.45 0.45], ...
    'oscillatory power (1/f-corrected)');

sgtitle(['1/f-corrected (IRASA) difference, ' ttl_base])
report_clusters_freq('Oscillatory power (a.u.)', CL_abs, freq_grid, alpha);
report_clusters_freq('Oscillatory power (dB)',  CL_db,  freq_grid, alpha);
if save_figs, save_figure(fig6, fullfile(out_folder, 'irasa_difference'), fig_format); end

%% Save numbers
if save_figs
    save(fullfile(out_folder, 'spectra_irasa_context.mat'), 'G', 'freq_grid', 'bands', ...
        'subjects', 'fit_range', 'smooth_for_spectra');
end

%% =============================
%% Local functions
%% =============================
function spectrum_figures(f, Ycer, Yunc, dbfac, qname, bands, band_scale, col_cer, col_unc, ...
                          n_perm, cluster_alpha, alpha, semfun, ttl_base, save_figs, out_folder, fig_format)
% Two figures for one spectral quantity (power: dbfac = 10, amplitude: dbfac = 20):
%   conditions: linear spectrum, log spectrum, paired band bars
%   difference: linear and dB difference spectra with cluster tests, band difference bars
nS = size(Ycer,1); nB = size(bands,1);
Qname = [upper(qname(1)) qname(2:end)];

Bc = zeros(nS, nB); Bu = zeros(nS, nB);
for b = 1:nB
    fi = f >= bands(b,1) & f <= bands(b,2);
    Bc(:,b) = mean(Ycer(:,fi), 2);
    Bu(:,b) = mean(Yunc(:,fi), 2);
end
if strcmpi(band_scale, 'dB')
    Bc = dbfac*log10(Bc); Bu = dbfac*log10(Bu); unit = 'dB';
else
    unit = 'a.u.';
end

% conditions
figC = figure('Color','w','Position',[100 100 1300 420]);
subplot(1,3,1); hold on
cond_spectrum_panel(f, Ycer, Yunc, col_cer, col_unc, bands, semfun, sprintf('%s (a.u.)', Qname), ...
    sprintf('%s spectrum', Qname));
subplot(1,3,2); hold on
cond_spectrum_panel(f, dbfac*log10(Ycer), dbfac*log10(Yunc), col_cer, col_unc, bands, semfun, ...
    sprintf('%s (dB)', Qname), sprintf('Log %s spectrum', qname));
subplot(1,3,3); hold on
cond_bar_panel(Bc, Bu, bands, sprintf('Band %s (%s)', qname, unit), col_cer, col_unc);
sgtitle(sprintf('%s spectrum, certain vs uncertain - %s', Qname, ttl_base))
print_paired_bands(sprintf('Band %s (%s), uncertain vs certain', qname, unit), Bc, Bu, bands);
if save_figs, save_figure(figC, fullfile(out_folder, [qname '_conditions']), fig_format); end

% difference
D_lin = Yunc - Ycer;
D_db  = dbfac*log10(Yunc) - dbfac*log10(Ycer);
CLl = cluster_perm_paired(D_lin, n_perm, cluster_alpha);
CLd = cluster_perm_paired(D_db,  n_perm, cluster_alpha);

figD = figure('Color','w','Position',[100 100 1300 420]);
subplot(1,3,1); hold on
diff_spectrum_panel(f, D_lin, CLl, bands, alpha, semfun, sprintf('\\Delta %s (a.u.)', qname));
title_with_clusters(sprintf('%s: uncertain - certain', Qname), CLl, f, alpha);
subplot(1,3,2); hold on
diff_spectrum_panel(f, D_db, CLd, bands, alpha, semfun, sprintf('\\Delta %s (dB)', qname));
title_with_clusters(sprintf('Log %s: uncertain - certain', qname), CLd, f, alpha);
subplot(1,3,3); hold on
band_bar_panel(Bu - Bc, bands, sprintf('\\Delta band %s (%s)', qname, unit), [0.45 0.45 0.45], qname);
sgtitle(sprintf('%s spectrum, uncertain - certain - %s', Qname, ttl_base))
report_clusters_freq(sprintf('%s (a.u.)', Qname), CLl, f, alpha);
report_clusters_freq(sprintf('%s (dB)', Qname), CLd, f, alpha);
if save_figs, save_figure(figD, fullfile(out_folder, [qname '_difference']), fig_format); end
end

function print_paired_bands(name, Bc, Bu, bands)
nB = size(bands,1); p_raw = zeros(nB,1); t = zeros(nB,1);
for b = 1:nB
    [~, p_raw(b), ~, st] = ttest(Bu(:,b), Bc(:,b)); t(b) = st.tstat;
end
p_h = holm(p_raw);
fprintf('\n%s (paired t-tests):\n', name);
for b = 1:nB
    d = Bu(:,b) - Bc(:,b);
    fprintf('  %2d-%2d Hz: t(%d) = %6.2f, p = %.4f, p_Holm = %.4f, dz = %5.2f\n', bands(b,1), bands(b,2), ...
        size(Bc,1)-1, t(b), p_raw(b), p_h(b), mean(d)/std(d));
end
end

function h = plot_shaded(x, Y, col, semfun)
m  = mean(Y, 1, 'omitnan'); se = semfun(Y);
x  = x(:)'; m = m(:)'; se = se(:)';
fill([x fliplr(x)], [m+se fliplr(m-se)], col, 'FaceAlpha', 0.25, 'EdgeColor', 'none');
h = plot(x, m, 'Color', col, 'LineWidth', 2);
end

function shade_bands(bands, yl)
for b = 1:size(bands,1)
    hp = patch(bands(b,[1 2 2 1]), yl([1 1 2 2]), [0.85 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
    uistack(hp, 'bottom');
end
end

function cond_spectrum_panel(f, Ycer, Yunc, col_cer, col_unc, bands, semfun, ylab, ttl)
mc = mean(Ycer, 1, 'omitnan'); sc = semfun(Ycer);
mu = mean(Yunc, 1, 'omitnan'); su = semfun(Yunc);
yl = [min([mc - sc, mu - su]) max([mc + sc, mu + su])];
yl = yl + [-1 1] * 0.05 * diff(yl);
shade_bands(bands, yl);
h1 = plot_shaded(f, Ycer, col_cer, semfun);
h2 = plot_shaded(f, Yunc, col_unc, semfun);
xlim(f([1 end])); ylim(yl)
xlabel('Frequency (Hz)'); ylabel(ylab); box on
legend([h1 h2], {'Certain','Uncertain'}, 'Location','best')
title(ttl, 'FontWeight', 'normal')
end

function cond_bar_panel(Bcer, Bunc, bands, ylab, col_cer, col_unc)
[nS, nB] = size(Bcer);
p_raw = zeros(nB,1);
for b = 1:nB, [~, p_raw(b)] = ttest(Bunc(:,b), Bcer(:,b)); end
p_holm = holm(p_raw);
allv = [Bcer(:); Bunc(:)];
lo = min(allv); hi = max(allv); pad = 0.06 * (hi - lo);
w = 0.35; jit = 0.08;
for b = 1:nB
    xc = b - w/2; xu = b + w/2;
    bar(xc, mean(Bcer(:,b)), w, 'FaceColor', col_cer, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    bar(xu, mean(Bunc(:,b)), w, 'FaceColor', col_unc, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    jx = (rand(nS,1) - 0.5) * jit;
    for s = 1:nS
        plot([xc xu] + jx(s), [Bcer(s,b) Bunc(s,b)], '-', 'Color', [0.75 0.75 0.75]);
    end
    scatter(xc + jx, Bcer(:,b), 18, 'k', 'filled', 'MarkerFaceAlpha', 0.6);
    scatter(xu + jx, Bunc(:,b), 18, 'k', 'filled', 'MarkerFaceAlpha', 0.6);
    errorbar(xc, mean(Bcer(:,b)), std(Bcer(:,b))/sqrt(nS), 'k', 'LineWidth', 1.5, 'CapSize', 6);
    errorbar(xu, mean(Bunc(:,b)), std(Bunc(:,b))/sqrt(nS), 'k', 'LineWidth', 1.5, 'CapSize', 6);
    ytop = max([Bcer(:,b); Bunc(:,b)]) + pad;
    plot([xc xu], ytop * [1 1], 'k-');
    text(b, ytop + 0.3*pad, sprintf('%s p = %.3f', sig_stars(p_holm(b)), p_holm(b)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
end
ylim([lo - pad, hi + 3.5*pad]); xlim([0.4 nB + 0.6])
set(gca, 'XTick', 1:nB, 'XTickLabel', arrayfun(@(b) sprintf('%d-%d Hz', bands(b,1), bands(b,2)), ...
    1:nB, 'UniformOutput', false))
ylabel(ylab); box on
title('Mean \pm SEM; paired t-test, p Holm-corrected', 'FontWeight', 'normal')
end

function diff_spectrum_panel(f, D, CL, bands, alpha, semfun, ylab)
m  = mean(D, 1, 'omitnan'); se = semfun(D);
yl = [min(m - se) max(m + se)];
yl = yl + [-1 1] * 0.15 * diff(yl);
shade_bands(bands, yl);
for c = 1:numel(CL)
    if CL(c).p < alpha
        f1 = f(CL(c).idx(1)); f2 = f(CL(c).idx(end));
        hp = patch([f1 f2 f2 f1], yl([1 1 2 2]), [1 0.85 0.4], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
        uistack(hp, 'bottom');
    end
end
plot_shaded(f, D, [0.4 0.4 0.4], semfun);
yline(0, 'k:');
xlim(f([1 end])); ylim(yl)
xlabel('Frequency (Hz)'); ylabel(ylab); box on
end

function title_with_clusters(base, CL, f, alpha)
txt = {base};
for c = 1:numel(CL)
    if CL(c).p < alpha
        txt{end+1} = sprintf('cluster %.1f-%.1f Hz, p = %.3f', f(CL(c).idx(1)), f(CL(c).idx(end)), CL(c).p); %#ok<AGROW>
    end
end
if numel(txt) == 1, txt{end+1} = 'no significant cluster'; end
title(txt, 'FontWeight', 'normal')
end

function report_clusters_freq(name, CL, f, alpha)
fprintf('\nCluster test, %s, uncertain - certain:\n', name);
if isempty(CL), fprintf('  No clusters exceeded the cluster-forming threshold.\n'); end
for c = 1:numel(CL)
    fprintf('  %s cluster %.2f-%.2f Hz: mass = %.2f, p = %.4f%s\n', CL(c).sign_label, ...
        f(CL(c).idx(1)), f(CL(c).idx(end)), CL(c).mass, CL(c).p, repmat(' *', 1, CL(c).p < alpha));
end
end

function band_bar_panel(D, bands, ylab, col, name)
[nS, nB] = size(D);
p_raw = zeros(nB,1); tstat = zeros(nB,1); dz = zeros(nB,1);
for b = 1:nB
    [~, p_raw(b), ~, st] = ttest(D(:,b));
    tstat(b) = st.tstat; dz(b) = mean(D(:,b)) / std(D(:,b));
end
p_holm = holm(p_raw);
lo = min([D(:); 0]); hi = max([D(:); 0]); pad = 0.06 * (hi - lo);
w = 0.55; jit = 0.18;
for b = 1:nB
    bar(b, mean(D(:,b)), w, 'FaceColor', col, 'EdgeColor', 'none', 'FaceAlpha', 0.35);
    scatter(b + (rand(nS,1) - 0.5) * jit, D(:,b), 20, 'k', 'filled', 'MarkerFaceAlpha', 0.6);
    errorbar(b, mean(D(:,b)), std(D(:,b))/sqrt(nS), 'k', 'LineWidth', 1.5, 'CapSize', 8);
    text(b, max(D(:,b)) + pad, sprintf('%s p = %.3f', sig_stars(p_holm(b)), p_holm(b)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
end
yline(0, 'k-');
ylim([lo - pad, hi + 3*pad]); xlim([0.4 nB + 0.6])
set(gca, 'XTick', 1:nB, 'XTickLabel', arrayfun(@(b) sprintf('%d-%d Hz', bands(b,1), bands(b,2)), ...
    1:nB, 'UniformOutput', false))
ylabel(ylab); box on
title('Uncertain - certain (mean \pm SEM; p Holm-corrected)', 'FontWeight', 'normal')
fprintf('\nBand %s, uncertain - certain (t-test vs 0 = paired t-test):\n', name);
for b = 1:nB
    fprintf('  %2d-%2d Hz: mean diff = %7.4f, t(%d) = %6.2f, p = %.4f, p_Holm = %.4f, dz = %5.2f\n', ...
        bands(b,1), bands(b,2), mean(D(:,b)), nS-1, tstat(b), p_raw(b), p_holm(b), dz(b));
end
end

function paired_distribution(v1, v2, c1, c2)
n = numel(v1); jit = (rand(n,1) - 0.5) * 0.08;
for i = 1:n
    plot([1 2] + jit(i), [v1(i) v2(i)], '-', 'Color', [0.8 0.8 0.8]);
end
half_density(v1, 1, -1, c1);
half_density(v2, 2, +1, c2);
scatter(1 + jit, v1, 30, c1, 'filled', 'MarkerFaceAlpha', 0.8);
scatter(2 + jit, v2, 30, c2, 'filled', 'MarkerFaceAlpha', 0.8);
errorbar(1, mean(v1), std(v1)/sqrt(n), 'k', 'LineWidth', 2, 'CapSize', 0);
errorbar(2, mean(v2), std(v2)/sqrt(n), 'k', 'LineWidth', 2, 'CapSize', 0);
plot([1 2], [mean(v1) mean(v2)], 'k-', 'LineWidth', 2);
scatter([1 2], [mean(v1) mean(v2)], 70, 'k', 'filled');
xlim([0.3 2.7]); set(gca, 'XTick', [1 2], 'XTickLabel', {'Certain','Uncertain'}); box on
end

function half_density(v, xpos, side, col)
v = v(~isnan(v));
grid = linspace(min(v) - 0.5*std(v), max(v) + 0.5*std(v), 200);
d = ksdensity(v, grid); d = d / max(d) * 0.35;
plot(xpos + side * (0.08 + d), grid, 'Color', col, 'LineWidth', 2);
plot(xpos + side * 0.08 * [1 1], grid([1 end]), 'Color', col, 'LineWidth', 0.5);
end

function CL = cluster_perm_paired(D, n_perm, cluster_alpha)
D      = D(~any(isnan(D), 2), :);
nS     = size(D, 1);
t_crit = tinv(1 - cluster_alpha/2, nS - 1);
tval   = @(X) mean(X, 1) ./ (std(X, 0, 1) ./ sqrt(size(X, 1)));
CL     = find_clusters(tval(D), t_crit);
max_mass = zeros(n_perm, 1);
for p = 1:n_perm
    cl_p = find_clusters(tval(D .* sign(rand(nS, 1) - 0.5)), t_crit);
    if ~isempty(cl_p), max_mass(p) = max(abs([cl_p.mass])); end
end
for c = 1:numel(CL)
    CL(c).p = (sum(max_mass >= abs(CL(c).mass)) + 1) / (n_perm + 1);
end
end

function CL = find_clusters(t, t_crit)
CL = struct('idx', {}, 'mass', {}, 'sign_label', {}, 'p', {});
signs = [1 -1]; labels = {'Positive', 'Negative'};
for k = 1:2
    d = diff([0 ((signs(k) * t) > t_crit) 0]);
    starts = find(d == 1); stops = find(d == -1) - 1;
    for c = 1:numel(starts)
        idx = starts(c):stops(c);
        CL(end+1) = struct('idx', idx, 'mass', sum(t(idx)), 'sign_label', labels{k}, 'p', NaN); %#ok<AGROW>
    end
end
end

function p_adj = holm(p)
p = p(:); m = numel(p);
[ps, order] = sort(p);
adj = min(1, cummax((m - (1:m)' + 1) .* ps));
p_adj = zeros(m,1); p_adj(order) = adj;
end

function s = sig_stars(p)
if p < 0.001, s = '***'; elseif p < 0.01, s = '**'; elseif p < 0.05, s = '*'; else, s = 'n.s.'; end
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
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
