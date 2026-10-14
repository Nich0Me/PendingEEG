clear all
close all

%% =============================
% Add FieldTrip
%% =============================
addpath('./Toolbox/fieldtrip-20220514')
ft_defaults

%% =============================
% PARAMETERS
%% =============================
cue_first   = 0;
data_folder = './Preprocessed/';
subjects = [1:20, 22:28, 30];

%% =============================
% STORAGE
%% =============================
s_counter = 0;

mean_rate_resp1 = [];
mean_rate_resp0 = [];
mean_rate_ctx1  = [];
mean_rate_ctx0  = [];
mean_rate_null1 = [];
mean_rate_null0 = [];

%% =============================
% LOOP
%% =============================
for subj = subjects

    s_counter = s_counter + 1;
    fprintf('Processing subject %d\n', subj);

    %% LOAD
    if cue_first == 1
        Day1Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day1-CuePreprocessed.mat']));
        Day2Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day2-CuePreprocessed.mat']));
    else
        Day1Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day1-StimPreprocessed.mat']));
        Day2Res = load(fullfile([data_folder,'sbj_',num2str(subj),'_Day2-StimPreprocessed.mat']));
    end

    %% APPEND
    cfg = [];
    data = ft_appenddata(cfg, Day1Res.preprocessed, Day2Res.preprocessed);

    %% SELECT TRIALS
    cfg = [];
    cfg.latency = [-4 1.5];
    cfg.trials = find(data.trialinfo(:,6) == 1);
    data = ft_selectdata(cfg, data);

    %% BUILD MATRICES
    nTrials = length(data.trial);
    time_vec = data.time{1};

    data_mat = zeros(nTrials, size(data.trial{1},1), size(data.trial{1},2));
    indices_mat = zeros(nTrials,3);
    cond_certainty = false(nTrials,1);

    for tr = 1:nTrials
        data_mat(tr,:,:) = data.trial{tr};
        indices_mat(tr,:) = data.trialinfo(tr,[3,5,8]);

        cond_certainty(tr) = data.trialinfo(tr,9)==1 || data.trialinfo(tr,9)==4;

        if indices_mat(tr,1) == 2
            indices_mat(tr,1) = -1;
        end
        if indices_mat(tr,3) == 0
            indices_mat(tr,3) = -1;
        end
    end

    indices_mat(:,2) = [];
    indices_mat = [ones(nTrials,1), indices_mat];

    context = indices_mat(:,2);
    motor   = indices_mat(:,3);

    X = [motor context ones(nTrials,1)];

    %% =============================
    % TASK AXES (GLM)
    %% =============================
    toi = [0.1 0.4];
    time_idx = time_vec > toi(1) & time_vec < toi(2);

    Yavg = squeeze(mean(data_mat(:,:,time_idx),3));
    Yavg = zscore(Yavg,0,1);

    betas = (X' * X) \ (X' * Yavg);

    W = [betas(1,:)' betas(2,:)'];

    %% =============================
    % PROJECT DATA
    %% =============================
    Z = zeros(nTrials, size(data_mat,3), 2);

    win = 20;
    hw = floor(win/2);

    for t = 1:size(data_mat,3)
        t1 = max(1, t-hw);
        t2 = min(size(data_mat,3), t+hw);

        Xt = squeeze(mean(data_mat(:,:,t1:t2),3));
        Z(:,t,:) = Xt * W;
    end

    %% =============================
    % FLICKER (TASK FIRST)
    %% =============================
    toi2 = [-4 -3.1];
    time_idx2 = time_vec > toi2(1) & time_vec < toi2(2);
    window_duration = toi2(2) - toi2(1);

    for tr = 1:nTrials

        % MOTOR
        traj = squeeze(Z(tr,time_idx2,1));
        thr = 0.5 * std(traj);

        state = zeros(size(traj));
        state(traj > thr) = 1;
        state(traj < -thr) = -1;

        s = state(state~=0);
        n_flips_resp(tr) = sum(abs(diff(s))==2);
        flicker_rate_resp(tr) = n_flips_resp(tr)/window_duration;

        % CONTEXT
        traj = squeeze(Z(tr,time_idx2,2));
        thr = 0.5 * std(traj);

        state = zeros(size(traj));
        state(traj > thr) = 1;
        state(traj < -thr) = -1;

        s = state(state~=0);
        n_flips_ctx(tr) = sum(abs(diff(s))==2);
        flicker_rate_ctx(tr) = n_flips_ctx(tr)/window_duration;
    end

    %% =============================
    % NULL SPACE (AFTER FLICKER)
    %% =============================
    data_res = zeros(size(data_mat));

    for t = 1:size(data_mat,3)
        Xt = squeeze(data_mat(:,:,t));
        B = (X' * X) \ (X' * Xt);
        Xt_hat = X * B;
        data_res(:,:,t) = Xt - Xt_hat;
    end

    %% PCA NULL
    X_pca = [];
    for t = find(time_idx2)
        t1 = max(1, t-hw);
        t2 = min(size(data_res,3), t+hw);
        X_pca = [X_pca; squeeze(mean(data_res(:,:,t1:t2),3))];
    end

    [coeff,~,~] = pca(X_pca);
    pc1 = coeff(:,1);

    %% PROJECT NULL
    Z_null = zeros(nTrials, length(time_vec));

    for t = 1:length(time_vec)
        t1 = max(1, t-hw);
        t2 = min(size(data_res,3), t+hw);
        Xt = squeeze(mean(data_res(:,:,t1:t2),3));
        Z_null(:,t) = Xt * pc1;
    end

    %% NULL FLICKER
    for tr = 1:nTrials

        traj = Z_null(tr,time_idx2);
        thr = 0.5 * std(traj);

        state = zeros(size(traj));
        state(traj > thr) = 1;
        state(traj < -thr) = -1;

        s = state(state~=0);
        n_flips_null(tr) = sum(abs(diff(s))==2);
        flicker_rate_null(tr) = n_flips_null(tr)/window_duration;
    end

    %% STORE
    mean_rate_resp1(s_counter) = mean(flicker_rate_resp(cond_certainty));
    mean_rate_resp0(s_counter) = mean(flicker_rate_resp(~cond_certainty));

    mean_rate_ctx1(s_counter) = mean(flicker_rate_ctx(cond_certainty));
    mean_rate_ctx0(s_counter) = mean(flicker_rate_ctx(~cond_certainty));

    mean_rate_null1(s_counter) = mean(flicker_rate_null(cond_certainty));
    mean_rate_null0(s_counter) = mean(flicker_rate_null(~cond_certainty));

end

%% =============================
% STATS
%% =============================
[~,p_motor,~,stats_motor] = ttest(mean_rate_resp1, mean_rate_resp0);
[~,p_ctx,~,stats_ctx] = ttest(mean_rate_ctx1, mean_rate_ctx0);
[~,p_null,~,stats_null] = ttest(mean_rate_null1, mean_rate_null0);

%% =============================
% FIGURE
%% =============================
figure('Color','w','Position',[100 100 1200 400]);
jitter = 0.05;

subplot(1,3,1); hold on
bar([1 2],[mean(mean_rate_resp1),mean(mean_rate_resp0)])
errorbar([1 2],[mean(mean_rate_resp1),mean(mean_rate_resp0)],...
    [std(mean_rate_resp1),std(mean_rate_resp0)]/sqrt(length(subjects)),'k','LineStyle','none')
scatter(1+(rand(size(mean_rate_resp1))-0.5)*jitter,mean_rate_resp1,'k','filled')
scatter(2+(rand(size(mean_rate_resp0))-0.5)*jitter,mean_rate_resp0,'k','filled')
title(sprintf('Motor (p=%.3f)',p_motor))
set(gca,'XTick',[1 2],'XTickLabel',{'Certain','Uncertain'})
ylabel('Flicker rate')
grid on

subplot(1,3,2); hold on
bar([1 2],[mean(mean_rate_ctx1),mean(mean_rate_ctx0)])
errorbar([1 2],[mean(mean_rate_ctx1),mean(mean_rate_ctx0)],...
    [std(mean_rate_ctx1),std(mean_rate_ctx0)]/sqrt(length(subjects)),'k','LineStyle','none')
scatter(1+(rand(size(mean_rate_ctx1))-0.5)*jitter,mean_rate_ctx1,'k','filled')
scatter(2+(rand(size(mean_rate_ctx0))-0.5)*jitter,mean_rate_ctx0,'k','filled')
title(sprintf('Context (p=%.3f)',p_ctx))
set(gca,'XTick',[1 2],'XTickLabel',{'Certain','Uncertain'})
grid on

subplot(1,3,3); hold on
bar([1 2],[mean(mean_rate_null1),mean(mean_rate_null0)])
errorbar([1 2],[mean(mean_rate_null1),mean(mean_rate_null0)],...
    [std(mean_rate_null1),std(mean_rate_null0)]/sqrt(length(subjects)),'k','LineStyle','none')
scatter(1+(rand(size(mean_rate_null1))-0.5)*jitter,mean_rate_null1,'k','filled')
scatter(2+(rand(size(mean_rate_null0))-0.5)*jitter,mean_rate_null0,'k','filled')
title(sprintf('Null (p=%.3f)',p_null))
set(gca,'XTick',[1 2],'XTickLabel',{'Certain','Uncertain'})
grid on

sgtitle('Flicker: Task vs Null')

%% PRINT STATS
fprintf('\n=== STATS ===\n')
fprintf('Motor:   t(%d)=%.3f, p=%.4f\n',stats_motor.df,stats_motor.tstat,p_motor)
fprintf('Context: t(%d)=%.3f, p=%.4f\n',stats_ctx.df,stats_ctx.tstat,p_ctx)
fprintf('Null:    t(%d)=%.3f, p=%.4f\n',stats_null.df,stats_null.tstat,p_null)

%% =============================
% FIGURE: Difference (Uncertain - Certain)
%% =============================
diff_motor = mean_rate_resp0 - mean_rate_resp1;
diff_ctx   = mean_rate_ctx0  - mean_rate_ctx1;
diff_null  = mean_rate_null0 - mean_rate_null1;

[~,p_diff_motor,~,stats_diff_motor] = ttest(diff_motor);
[~,p_diff_ctx,~,stats_diff_ctx]     = ttest(diff_ctx);
[~,p_diff_null,~,stats_diff_null]   = ttest(diff_null);

figure('Color','w','Position',[100 100 1200 400]);

subplot(1,3,1); hold on
bar(1, mean(diff_motor), 0.4, 'FaceColor',[0.2 0.6 0.8])
errorbar(1, mean(diff_motor), std(diff_motor)/sqrt(length(subjects)), 'k', 'LineWidth',1.5)
scatter(1+(rand(size(diff_motor))-0.5)*jitter, diff_motor, 40, 'k', 'filled', 'MarkerFaceAlpha',0.7)
yline(0,'--k')
xlim([0.5 1.5])
set(gca,'XTick',1,'XTickLabel',{'Uncertain - Certain'})
ylabel('Flicker rate difference (Hz)')
title(sprintf('Motor (t=%.2f, p=%.3f)', stats_diff_motor.tstat, p_diff_motor))
grid on
ylim([-0.6,1])

subplot(1,3,2); hold on
bar(1, mean(diff_ctx), 0.4, 'FaceColor',[0.2 0.6 0.8])
errorbar(1, mean(diff_ctx), std(diff_ctx)/sqrt(length(subjects)), 'k', 'LineWidth',1.5)
scatter(1+(rand(size(diff_ctx))-0.5)*jitter, diff_ctx, 40, 'k', 'filled', 'MarkerFaceAlpha',0.7)
yline(0,'--k')
xlim([0.5 1.5])
set(gca,'XTick',1,'XTickLabel',{'Uncertain - Certain'})
title(sprintf('Context (t=%.2f, p=%.3f)', stats_diff_ctx.tstat, p_diff_ctx))
grid on
ylim([-0.6,1])

subplot(1,3,3); hold on
bar(1, mean(diff_null), 0.4, 'FaceColor',[0.2 0.6 0.8])
errorbar(1, mean(diff_null), std(diff_null)/sqrt(length(subjects)), 'k', 'LineWidth',1.5)
scatter(1+(rand(size(diff_null))-0.5)*jitter, diff_null, 40, 'k', 'filled', 'MarkerFaceAlpha',0.7)
yline(0,'--k')
xlim([0.5 1.5])
set(gca,'XTick',1,'XTickLabel',{'Uncertain - Certain'})
title(sprintf('Null (t=%.2f, p=%.3f)', stats_diff_null.tstat, p_diff_null))
grid on
ylim([-0.6,1])

sgtitle('Flicker rate difference: Uncertain - Certain')

fprintf('\n=== DIFFERENCE STATS ===\n')
fprintf('Motor:   t(%d)=%.3f, p=%.4f\n',stats_diff_motor.df,stats_diff_motor.tstat,p_diff_motor)
fprintf('Context: t(%d)=%.3f, p=%.4f\n',stats_diff_ctx.df,stats_diff_ctx.tstat,p_diff_ctx)
fprintf('Null:    t(%d)=%.3f, p=%.4f\n',stats_diff_null.df,stats_diff_null.tstat,p_diff_null)
