clear all
close all

%% Parameters
cue_first  = 0;
data_folder = './Preprocessed/';
subjects = [1:20, 22:28, 30];

toi = [0.1 0.3];   % GLM time window (s)
rng(1);            % reproducibility

%% Storage
acc_motor_subj   = zeros(length(subjects),1);
acc_context_subj = zeros(length(subjects),1);

s_counter = 0;

%% ===============================
%  Loop over subjects
% ===============================
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
    cfg.latency = [-4 1.5];
    data = ft_selectdata(cfg, data);

    %% ===============================
    % Extract trials
    % ===============================
    nTrials  = length(data.trial);
    time_vec = data.time{1};

    nChan = size(data.trial{1},1);
    nTime = size(data.trial{1},2);

    data_mat = zeros(nTrials, nChan, nTime);
    indices_mat = zeros(nTrials,3);

    for tr = 1:nTrials
        data_mat(tr,:,:) = data.trial{tr};
        indices_mat(tr,:) = data.trialinfo(tr,[3,5,8]);

        % recode to ±1
        if indices_mat(tr,1) == 2
            indices_mat(tr,1) = -1;
        end
        if indices_mat(tr,3) == 0
            indices_mat(tr,3) = -1;
        end
    end

    %% Behavioural variables
    RT = indices_mat(:,2); %#ok<NASGU>
    indices_mat(:,2) = [];

    intercept = ones(nTrials,1);
    context   = indices_mat(:,1);
    motor     = indices_mat(:,2);

    %% Design matrix
    X = [motor context intercept];

    y_motor   = motor;
    y_context = context;

    %% ===============================
    % Time window averaging
    % ===============================
    time_idx = time_vec > toi(1) & time_vec < toi(2);

    Yavg = squeeze(mean(data_mat(:,:,time_idx),3)); % trials × channels
    Yavg = zscore(Yavg,0,1); % normalize per channel

    %% ===============================
    % 80 / 20 TRAIN–TEST SPLIT
    % ===============================
    cv = cvpartition(nTrials,'HoldOut',0.15);

    train_idx = training(cv);
    test_idx  = test(cv);

    Xtrain = X(train_idx,:);
    Ytrain = Yavg(train_idx,:);
    Ytest  = Yavg(test_idx,:);

    %% ===============================
    % Fit GLM (training only)
    % ===============================
    betas = (Xtrain' * Xtrain) \ (Xtrain' * Ytrain);

    beta_motor   = betas(1,:)';
    beta_context = betas(2,:)';

    W = [beta_motor beta_context]; % channels × 2

    %% ===============================
    % Project held-out trials
    % ===============================
    Ztest = Ytest * W;

    %% Decode
    pred_motor   = sign(Ztest(:,1));
    pred_context = sign(Ztest(:,2));

    acc_motor_subj(s_counter)   = mean(pred_motor   == y_motor(test_idx));
    acc_context_subj(s_counter) = mean(pred_context == y_context(test_idx));

end

%% ===============================
% Group summary
% ===============================
fprintf('\nGLM decoding (80/20 split):\n');
fprintf('Motor   : %.3f ± %.3f\n', ...
    mean(acc_motor_subj), ...
    std(acc_motor_subj)/sqrt(length(subjects)));

fprintf('Context : %.3f ± %.3f\n', ...
    mean(acc_context_subj), ...
    std(acc_context_subj)/sqrt(length(subjects)));

%% ===============================
% Plot
% ===============================
figure('Color','w'); hold on

means = [mean(acc_motor_subj) mean(acc_context_subj)];
errs  = [std(acc_motor_subj) std(acc_context_subj)] ...
        ./ sqrt(length(subjects));

bar([1 2], means, 0.5)
errorbar([1 2], means, errs, ...
    'k','LineWidth',1.5,'LineStyle','none')

set(gca,'XTick',[1 2],...
        'XTickLabel',{'Motor','Context'},...
        'FontSize',12)

ylabel('Decoding accuracy')
yline(0.5,'--','Chance')

ylim([0.4 1])
grid on
title('GLM decoding (80/20 train–test split)')