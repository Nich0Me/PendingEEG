clear all
%close all

addpath('./Toolbox/fieldtrip-20220514')
ft_defaults

cue_first = 0;
if cue_first == 1
Day1Res = load(fullfile(['./Preprocessed/sbj_',num2str(1),'_Day1-CuePreprocessed.mat']));
else
Day1Res = load(fullfile(['./Preprocessed/sbj_',num2str(1),'_Day1-StimPreprocessed.mat']));
end

cfg = [];
cfg.resamplefs = 100;
Day1Res.preprocessed = ft_resampledata(cfg,Day1Res.preprocessed);
%Day2Res.preprocessed = ft_resampledata(cfg,Day2Res.preprocessed);

if cue_first==1
    cfg = [];
    cfg.latency = [-0.2, 4];
    Day1Res.preprocessed = ft_selectdata(cfg, Day1Res.preprocessed);
    %Day2Res.preprocessed = ft_selectdata(cfg, Day2Res.preprocessed);
else
    cfg = [];
    cfg.latency = [-3.2, 1];
    Day1Res.preprocessed = ft_selectdata(cfg, Day1Res.preprocessed);
    %Day2Res.preprocessed = ft_selectdata(cfg, Day2Res.preprocessed);
end

counter_s = 0;
for s = [1:20, 22:28, 30]
    counter_s = counter_s + 1;
    if cue_first ==1
        load(['./Res_PreDicho/sbj',num2str(s),'_CueFirst'],'acc')
    else
        load(['./Res_PreDicho/sbj',num2str(s),'_StimFirst'],'acc')
    end

    acc_sbj(:,:,counter_s) = squeeze(mean(mean(acc,3),4));

end

figure
t = Day1Res.preprocessed.time{1};

%clim([0.45,0.6])

figure
%% =========================
%% Compute diagonal per subject
%% =========================

nSubj = size(acc_sbj,3);
nTime = size(acc_sbj,1);

accD_subj = nan(nTime, nSubj);

for s = 1:nSubj
    tmp = acc_sbj(:,:,s);
    accD_subj(:,s) = diag(tmp);
end

%% =========================
%% Group mean and SEM
%% =========================

mean_accD = mean(accD_subj,2);
sem_accD  = std(accD_subj,[],2) ./ sqrt(nSubj);

%% =========================
%% Plot
%% =========================

figure('Color','w'); hold on

% --- SEM shaded area ---
fill([t fliplr(t)], ...
     [mean_accD'+sem_accD' ...
      fliplr(mean_accD'-sem_accD')], ...
     [0.7 0.7 0.7], ...
     'EdgeColor','none', ...
     'FaceAlpha',0.4);

% --- Mean line ---
plot(t, mean_accD, 'k', 'LineWidth',2.5)

yline(0.5,'--k')
xline(0,'--k')

ylim([0.45 0.7])
xlabel('Time (s)')
ylabel('Accuracy')
box off

