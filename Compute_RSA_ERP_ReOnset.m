clear all
close all

addpath('/Users/menghi/Documents/MATLAB/Toolbox/fieldtrip-20220514')
ft_defaults

cue_first = 1;
data_folder = './Preprocessed/';

%2-Trial_n;
%3-Cue;
%4-Action;
%5-RT;
%6-Feedback;
%7-Missed;
%8-Outcome;
%9-Configuration;

counter = 1;
for s = [1:20,22:28,30]

    if cue_first == 1
        Day1Res = load(fullfile([data_folder,'sbj_',num2str(s),'_Day1-CuePreprocessed.mat']));
        Day2Res = load(fullfile([data_folder,'sbj_',num2str(s),'_Day2-CuePreprocessed.mat']));

    else
        Day1Res = load(fullfile([data_folder,'sbj_',num2str(s),'_Day1-StimPreprocessed.mat']));
        Day2Res = load(fullfile([data_folder,'sbj_',num2str(s),'_Day2-StimPreprocessed.mat']));
    end

    %% LP Filter Data
    cfg = [];
    cfg.lpfilter = 'yes';
    cfg.lpfreq = 30;

    Day1Res.preprocessed = ft_preprocessing(cfg, Day1Res.preprocessed);
    Day2Res.preprocessed = ft_preprocessing(cfg, Day2Res.preprocessed);

    cfg = [];
    cfg.resamplefs = 250;
    Day1Res.preprocessed = ft_resampledata(cfg,Day1Res.preprocessed);
    Day2Res.preprocessed = ft_resampledata(cfg,Day2Res.preprocessed);

    if cue_first==1
        cfg = [];
        cfg.latency = [-0.2, 4.5];
        Day1Res.preprocessed = ft_selectdata(cfg, Day1Res.preprocessed);
        Day2Res.preprocessed = ft_selectdata(cfg, Day2Res.preprocessed);
    else
        cfg = [];
        cfg.latency = [-3.2, 6.2];
        Day1Res.preprocessed = ft_selectdata(cfg, Day1Res.preprocessed);
        Day2Res.preprocessed = ft_selectdata(cfg, Day2Res.preprocessed);
    end


    Day1ResMat = nan(61,501,length(Day1Res.preprocessed.trial));
    for tr=1:length(Day1Res.preprocessed.trial)
        RT = Day1Res.preprocessed.trialinfo(tr,5);
        if cue_first==1
            RT = RT+1.5;
        else
            RT = RT;
        end
        [val,idx] = min(abs(Day1Res.preprocessed.time{tr} - RT));
        high_val = 250;
        if idx+250 > length(Day1Res.preprocessed.trial{tr})
            high_val = length(Day1Res.preprocessed.trial{tr})-idx;

        end
        Day1ResMat(:,1:251+high_val,tr) = Day1Res.preprocessed.trial{tr}(:,idx-250:idx+high_val);
    end

    Day2ResMat = nan(61,501,length(Day1Res.preprocessed.trial));
    for tr=1:length(Day2Res.preprocessed.trial)
        RT = Day2Res.preprocessed.trialinfo(tr,5);
        if cue_first==1
            RT = RT+1.5;
        else
            RT = RT;
        end
        [val,idx] = min(abs(Day2Res.preprocessed.time{tr} - RT));
        high_val = 250;
        if idx+250 > length(Day2Res.preprocessed.trial{tr})
            high_val = length(Day2Res.preprocessed.trial{tr})-idx;

        end
        Day2ResMat(:,1:251+high_val,tr) = Day2Res.preprocessed.trial{tr}(:,idx-250:idx+high_val);
    end

    %% ERP Context and Configuration
    % Conf 1 Context 1
    idx1 = find([Day1Res.preprocessed.trialinfo(:,3)]==1 & [Day1Res.preprocessed.trialinfo(:,7)]==0 & [Day1Res.preprocessed.trialinfo(:,9)]==1);
    idx2 = find([Day2Res.preprocessed.trialinfo(:,3)]==1 & [Day2Res.preprocessed.trialinfo(:,7)]==0 & [Day2Res.preprocessed.trialinfo(:,9)]==1);

    trial = cat(3, Day1ResMat(:,:,idx1), Day2ResMat(:,:,idx2));

    Conf1Cue1 = nanmean(trial,3);

    % Conf 2 Context 1
    idx1 = find([Day1Res.preprocessed.trialinfo(:,3)]==1 & [Day1Res.preprocessed.trialinfo(:,7)]==0 & [Day1Res.preprocessed.trialinfo(:,9)]==2);
    idx2 = find([Day2Res.preprocessed.trialinfo(:,3)]==1 & [Day2Res.preprocessed.trialinfo(:,7)]==0 & [Day2Res.preprocessed.trialinfo(:,9)]==2);

    trial = cat(3, Day1ResMat(:,:,idx1), Day2ResMat(:,:,idx2));

    Conf2Cue1 = nanmean(trial,3);

    % Conf 3 Context 1
    idx1 = find([Day1Res.preprocessed.trialinfo(:,3)]==1 & [Day1Res.preprocessed.trialinfo(:,7)]==0 & [Day1Res.preprocessed.trialinfo(:,9)]==3);
    idx2 = find([Day2Res.preprocessed.trialinfo(:,3)]==1 & [Day2Res.preprocessed.trialinfo(:,7)]==0 & [Day2Res.preprocessed.trialinfo(:,9)]==3);

    trial = cat(3, Day1ResMat(:,:,idx1), Day2ResMat(:,:,idx2));

    Conf3Cue1 = nanmean(trial,3);

    % Conf 4 Context 1
    idx1 = find([Day1Res.preprocessed.trialinfo(:,3)]==1 & [Day1Res.preprocessed.trialinfo(:,7)]==0 & [Day1Res.preprocessed.trialinfo(:,9)]==4);
    idx2 = find([Day2Res.preprocessed.trialinfo(:,3)]==1 & [Day2Res.preprocessed.trialinfo(:,7)]==0 & [Day2Res.preprocessed.trialinfo(:,9)]==4);

    trial = cat(3, Day1ResMat(:,:,idx1), Day2ResMat(:,:,idx2));

    Conf4Cue1 = nanmean(trial,3);

    % Conf 1 Context 2
    idx1 = find([Day1Res.preprocessed.trialinfo(:,3)]==2 & [Day1Res.preprocessed.trialinfo(:,7)]==0 & [Day1Res.preprocessed.trialinfo(:,9)]==1);
    idx2 = find([Day2Res.preprocessed.trialinfo(:,3)]==2 & [Day2Res.preprocessed.trialinfo(:,7)]==0 & [Day2Res.preprocessed.trialinfo(:,9)]==1);

    trial = cat(3, Day1ResMat(:,:,idx1), Day2ResMat(:,:,idx2));

    Conf1Cue2 = nanmean(trial,3);

    % Conf 2 Context 2
    idx1 = find([Day1Res.preprocessed.trialinfo(:,3)]==2 & [Day1Res.preprocessed.trialinfo(:,7)]==0 & [Day1Res.preprocessed.trialinfo(:,9)]==2);
    idx2 = find([Day2Res.preprocessed.trialinfo(:,3)]==2 & [Day2Res.preprocessed.trialinfo(:,7)]==0 & [Day2Res.preprocessed.trialinfo(:,9)]==2);

    trial = cat(3, Day1ResMat(:,:,idx1), Day2ResMat(:,:,idx2));

    Conf2Cue2 = nanmean(trial,3);

    % Conf 3 Context 2
    idx1 = find([Day1Res.preprocessed.trialinfo(:,3)]==2 & [Day1Res.preprocessed.trialinfo(:,7)]==0 & [Day1Res.preprocessed.trialinfo(:,9)]==3);
    idx2 = find([Day2Res.preprocessed.trialinfo(:,3)]==2 & [Day2Res.preprocessed.trialinfo(:,7)]==0 & [Day2Res.preprocessed.trialinfo(:,9)]==3);

    trial = cat(3, Day1ResMat(:,:,idx1), Day2ResMat(:,:,idx2));

    Conf3Cue2 = nanmean(trial,3);

    % Conf 4 Context 2
    idx1 = find([Day1Res.preprocessed.trialinfo(:,3)]==2 & [Day1Res.preprocessed.trialinfo(:,7)]==0 & [Day1Res.preprocessed.trialinfo(:,9)]==4);
    idx2 = find([Day2Res.preprocessed.trialinfo(:,3)]==2 & [Day2Res.preprocessed.trialinfo(:,7)]==0 & [Day2Res.preprocessed.trialinfo(:,9)]==4);

    trial = cat(3, Day1ResMat(:,:,idx1), Day2ResMat(:,:,idx2));

    Conf4Cue2 = nanmean(trial,3);

    time = -1:1/250:1;

    if cue_first == 1
        save(['./RSA_ERPs/sbj', num2str(s),'-CueFirst_reonset'],'Conf1Cue1','Conf2Cue1','Conf3Cue1','Conf4Cue1','Conf1Cue2','Conf2Cue2','Conf3Cue2','Conf4Cue2','time')
    else
        save(['./RSA_ERPs/sbj', num2str(s),'-StimFirst_reonset'],'Conf1Cue1','Conf2Cue1','Conf3Cue1','Conf4Cue1','Conf1Cue2','Conf2Cue2','Conf3Cue2','Conf4Cue2','time')
    end
end
