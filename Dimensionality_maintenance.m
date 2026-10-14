clear all
close all

%% Add FieldTrip
addpath('/Users/menghi/Documents/MATLAB/Toolbox/fieldtrip-20220514')
ft_defaults

%% Parameters
cue_first   = 0;
data_folder = './Preprocessed/';
time_window = [-3 0];   % seconds
subjects    = [1:20, 22:28, 30];
lp_filter   = 0;        % set to 1 to apply 30 Hz low-pass filter
lp_freq     = 30;

%% Storage
subj_mean_A = zeros(length(subjects),1);
subj_mean_B = zeros(length(subjects),1);

s_counter = 0;

%% Loop over subjects
for subj = subjects

    s_counter = s_counter + 1;
    fprintf('Processing subject %d\n', subj);

    %% Load data
    if cue_first == 1
        Day1Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day1-CuePreprocessed.mat']));
        Day2Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day2-CuePreprocessed.mat']));
    else
        Day1Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day1-StimPreprocessed.mat']));
        Day2Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day2-StimPreprocessed.mat']));
    end

    %% Append days
    cfg = [];
    data = ft_appenddata(cfg, Day1Res.preprocessed, Day2Res.preprocessed);

    %% Select latency
    cfg = [];
    cfg.latency = [-3.5 1.5];
    data = ft_selectdata(cfg, data);

    %% Optional low-pass filter
    if lp_filter
        cfg          = [];
        cfg.lpfilter = 'yes';
        cfg.lpfreq   = lp_freq;
        data         = ft_preprocessing(cfg, data);
    end

    %% Basic info
    nTrials = length(data.trial);
    time_vec = data.time{1};
    t_idx = time_vec >= time_window(1) & time_vec <= time_window(2);

    dim_trial = zeros(nTrials,1);
    indices_mat = zeros(nTrials, size(data.trialinfo,2));

    %% Loop trials
    for tr = 1:nTrials

        X = data.trial{tr}(:, t_idx);   % channels x time
        indices_mat(tr,:) = data.trialinfo(tr,:);

        % z-score per channel
        X = zscore(X, 0, 2);

        % covariance
        C = cov(X');  

        % eigenvalues
        eigvals = eig(C);
        eigvals = eigvals(eigvals > 1e-10);

        % participation ratio
        dim_trial(tr) = (sum(eigvals)^2) / sum(eigvals.^2);
    end

    %% Define conditions
    condA = indices_mat(:,9) == 1 | indices_mat(:,9) == 4;
    condB = indices_mat(:,9) == 2 | indices_mat(:,9) == 3;

    %% Subject-level means
    subj_mean_A(s_counter) = mean(dim_trial(condA));
    subj_mean_B(s_counter) = mean(dim_trial(condB));

end

%% -------- Group statistics --------

fprintf('\nGroup-level results:\n');
fprintf('Cond A mean = %.2f ± %.2f\n', mean(subj_mean_A), std(subj_mean_A));
fprintf('Cond B mean = %.2f ± %.2f\n', mean(subj_mean_B), std(subj_mean_B));

% Paired t-test (within-subject design)
[h,p,ci,stats] = ttest(subj_mean_A, subj_mean_B);

fprintf('\nPaired t-test: t(%d) = %.3f, p = %.5f\n', ...
    length(subjects)-1, stats.tstat, p);

%% -------- Plot --------

figure;
bar([mean(subj_mean_A-subj_mean_B)]);
hold on;

% SEM
semA = std(subj_mean_A-subj_mean_B) / sqrt(length(subj_mean_A));
%semB = std(subj_mean_B) / sqrt(length(subj_mean_B));

errorbar([1], ...
         [mean(subj_mean_A-subj_mean_B)], ...
         [semA], ...
         'k.', 'LineWidth', 1.5);

set(gca,'XTick', [1]);
set(gca,'XTickLabel', {'Cond 1&4-Cond 2&3'});
ylabel('Effective dimensionality (PR)');
title('Dimensionality by condition (subject-level)');
grid on;
