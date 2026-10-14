clear all
%close all

addpath('/Users/menghi/Documents/MATLAB/Toolbox/fieldtrip-20220514')
ft_defaults

cue_first = 1;
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
    cfg.latency = [-3.2, 2];
    Day1Res.preprocessed = ft_selectdata(cfg, Day1Res.preprocessed);
    %Day2Res.preprocessed = ft_selectdata(cfg, Day2Res.preprocessed);
end

counter_s = 0;
for s = [1:20, 22:28, 30]
    counter_s = counter_s + 1;
    if cue_first ==1
        load(['./Res_ClassStimulus4/sbj',num2str(s),'_CueFirst'],'acc')
    else
        load(['./Res_ClassStimulus4/sbj',num2str(s),'_StimFirst'],'acc')
    end

    acc_sbj(:,:,counter_s) = mean(acc,3);

end

figure
t = Day1Res.preprocessed.time{1};
%t = linspace(-1,1,201);
imagesc(t,t,squeeze(mean(acc_sbj,3)),[0.45, 0.6])

%clim([0.45,0.6])

figure
avg_acc = mean(acc_sbj,3);
%avg_acc = acc_sbj(:,:,4);
accD = avg_acc(logical(eye(size(squeeze(mean(acc_sbj,3))))));
plot(t, accD)
yline(0.5)
xline(0)
ylim([0.45, 0.85])
%xline(1)
title('10-Fold Cross-Validation Accuracy')
xlabel('Time (s)')
ylabel('Accuracy')


% % Extract the diagonal for each slice
% for i = 1:28
%     diagonals(:, i) = diag(acc_sbj(:, :, i));
% end
% 
% % Plot all 28 diagonals
% for i = 1:28
% figure;
% plot(diagonals(:,i))
% end
% xlabel('Diagonal index')
% ylabel('Value')
% title('Diagonals across the 28 slices')
