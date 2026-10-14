clear all
close all

%% Add FieldTrip
addpath('./Toolbox/fieldtrip-20220514')
ft_defaults

%% Parameters
cue_first   = 0;
data_folder = './Preprocessed/';
subjects = [1:20, 22:28, 30];

time_window_dim = [-3 -0.1];     % for dimensionality
toi_flicker     = [-3 -0.1];

%% Storage
corr_certain   = zeros(length(subjects),1);
corr_uncertain = zeros(length(subjects),1);

s_counter = 0;

%% Loop subjects
for subj = subjects

    s_counter = s_counter + 1;
    fprintf('Processing subject %d\n', subj);

    %% Load
    if cue_first == 1
        Day1Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day1-CuePreprocessed.mat']));
        Day2Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day2-CuePreprocessed.mat']));
    else
        Day1Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day1-StimPreprocessed.mat']));
        Day2Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day2-StimPreprocessed.mat']));
    end

    %% Append
    cfg = [];
    data = ft_appenddata(cfg, Day1Res.preprocessed, Day2Res.preprocessed);

    %% Select latency (wide window for both analyses)
    cfg = [];
    cfg.latency = [-4 1.5];
    data = ft_selectdata(cfg, data);

    %% Basic
    nTrials = length(data.trial);
    time_vec = data.time{1};

    t_idx_dim = time_vec >= time_window_dim(1) & time_vec <= time_window_dim(2);
    t_idx_flick = time_vec >= toi_flicker(1) & time_vec <= toi_flicker(2);

    dim_trial = zeros(nTrials,1);
    flicker_trial = zeros(nTrials,1);

    indices_mat = zeros(nTrials, size(data.trialinfo,2));

    %% Prepare GLM projection (same as script 2)
    data_mat = zeros(nTrials, size(data.trial{1},1), size(data.trial{1},2));

    for tr = 1:nTrials
        data_mat(tr,:,:) = data.trial{tr};
        indices_mat(tr,:) = data.trialinfo(tr,:);
    end

    cond_certainty = indices_mat(:,9)==1 | indices_mat(:,9)==4;

    %% Build GLM design
    idx = data.trialinfo(:,[3,5,8]);

    idx(idx(:,1)==2,1) = -1;
    idx(idx(:,3)==0,3) = -1;

    X = [idx(:,3) idx(:,1) ones(nTrials,1)];

    % Time window for GLM
    toi = [0.1 0.4];
    time_idx = time_vec>toi(1) & time_vec<toi(2);

    Yavg = squeeze(mean(data_mat(:,:,time_idx),3));
    Yavg = zscore(Yavg, 0, 1);

    betas = (X' * X) \ (X' * Yavg);

    W = [betas(1,:)' betas(2,:)'];

    %% Project data over time (smoothed)
    window_size = 20;
    half_win = floor(window_size/2);

    Z = zeros(nTrials, length(time_vec), 2);

    for t = 1:length(time_vec)
        t_start = max(1, t-half_win);
        t_end   = min(length(time_vec), t+half_win);

        Xt = squeeze(mean(data_mat(:,:,t_start:t_end),3));
        Z(:,t,:) = Xt * W;
    end

    %% ---- Trial loop ----
    for tr = 1:nTrials

        %% --- Dimensionality ---
        Xtr = data.trial{tr}(:, t_idx_dim);
        Xtr = zscore(Xtr, 0, 2);

        C = cov(Xtr');
        eigvals = eig(C);
        eigvals = eigvals(eigvals > 1e-10);

        dim_trial(tr) = (sum(eigvals)^2) / sum(eigvals.^2);

        %% --- Flicker (motor axis) ---
        traj = squeeze(Z(tr,t_idx_flick,1));

        thr = 0.5 * std(traj);

        state = zeros(size(traj));
        state(traj >  thr) =  1;
        state(traj < -thr) = -1;

        state = state(state ~= 0);

        n_flips = sum(abs(diff(state)) == 2);

        duration = toi_flicker(2) - toi_flicker(1);
        flicker_trial(tr) = n_flips / duration;
    end
    
    % --- Subject-level means per condition ---
    dim_certain(s_counter)   = mean(dim_trial(cond_certainty));
    dim_uncertain(s_counter) = mean(dim_trial(~cond_certainty));

    flick_certain(s_counter)   = mean(flicker_trial(cond_certainty));
    flick_uncertain(s_counter) = mean(flicker_trial(~cond_certainty));
    %% ---- Correlations per condition ----
    % remove NaNs just in case
    valid = ~isnan(dim_trial) & ~isnan(flicker_trial);

    % Certain
    idx_c = cond_certainty & valid;
    if sum(idx_c) > 5
        corr_certain(s_counter) = corr(dim_trial(idx_c), flicker_trial(idx_c));
    else
        corr_certain(s_counter) = NaN;
    end

    % Uncertain
    idx_u = ~cond_certainty & valid;
    if sum(idx_u) > 5
        corr_uncertain(s_counter) = corr(dim_trial(idx_u), flicker_trial(idx_u));
    else
        corr_uncertain(s_counter) = NaN;
    end



end

%% -------- Group stats --------
fprintf('\nCorrelation results:\n');
fprintf('Certain:   %.3f ± %.3f\n', nanmean(corr_certain), nanstd(corr_certain));
fprintf('Uncertain: %.3f ± %.3f\n', nanmean(corr_uncertain), nanstd(corr_uncertain));

% Paired t-test
[h,p,ci,stats] = ttest(corr_certain);
fprintf('t(%d)=%.3f, p=%.5f\n', length(subjects)-1, stats.tstat, p);

%% -------- Plot --------
figure;
hold on

bar(1, nanmean(corr_certain), 0.4);
bar(2, nanmean(corr_uncertain), 0.4);

errorbar(1, nanmean(corr_certain), nanstd(corr_certain)/sqrt(length(subjects)), 'k');
errorbar(2, nanmean(corr_uncertain), nanstd(corr_uncertain)/sqrt(length(subjects)), 'k');

% subject dots
jitter = 0.05;
scatter(1 + (rand(size(corr_certain))-0.5)*jitter, corr_certain, 40, 'k', 'filled');
scatter(2 + (rand(size(corr_uncertain))-0.5)*jitter, corr_uncertain, 40, 'k', 'filled');

xlim([0.5 2.5])
set(gca,'XTick',[1 2],'XTickLabel',{'Certain','Uncertain'})
ylabel('Correlation (Dimensionality vs Flicker)')
title('Trial-wise correlation per subject')
grid on


figure;
hold on

bar(1, mean(dim_certain), 0.4);
bar(2, mean(dim_uncertain), 0.4);

errorbar(1, mean(dim_certain), std(dim_certain)/sqrt(length(subjects)), 'k');
errorbar(2, mean(dim_uncertain), std(dim_uncertain)/sqrt(length(subjects)), 'k');

jitter = 0.05;
scatter(1 + (rand(size(dim_certain))-0.5)*jitter, dim_certain, 40, 'k', 'filled');
scatter(2 + (rand(size(dim_uncertain))-0.5)*jitter, dim_uncertain, 40, 'k', 'filled');

set(gca,'XTick',[1 2],'XTickLabel',{'Certain','Uncertain'})
ylabel('Dimensionality (PR)')
title('Dimensionality across conditions')
grid on

figure;
hold on

bar(1, mean(flick_certain), 0.4);
bar(2, mean(flick_uncertain), 0.4);

errorbar(1, mean(flick_certain), std(flick_certain)/sqrt(length(subjects)), 'k');
errorbar(2, mean(flick_uncertain), std(flick_uncertain)/sqrt(length(subjects)), 'k');

scatter(1 + (rand(size(flick_certain))-0.5)*jitter, flick_certain, 40, 'k', 'filled');
scatter(2 + (rand(size(flick_uncertain))-0.5)*jitter, flick_uncertain, 40, 'k', 'filled');

set(gca,'XTick',[1 2],'XTickLabel',{'Certain','Uncertain'})
ylabel('Flicker rate (Hz)')
title('Flicker across conditions')
grid on

figure;
hold on

dim_diff   = dim_uncertain - dim_certain;
flick_diff = flick_uncertain - flick_certain;

scatter(dim_diff, flick_diff, 60, 'k', 'filled');

% regression line
lsline

xlabel('Δ Dimensionality (Uncertain - Certain)')
ylabel('Δ Flicker (Uncertain - Certain)')
title('Relationship between dimensionality and flicker across subjects')
grid on

% correlation
[r,p] = corr(dim_certain', flick_certain', 'Type', 'Pearson');
text(min(dim_diff), max(flick_diff), sprintf('r = %.2f, p = %.3f', r, p));
