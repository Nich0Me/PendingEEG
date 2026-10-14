clear all
close all

addpath('./Toolbox/fieldtrip-20220514')
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

for s = 11:12

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
    cfg.resamplefs = 100;
    Day1Res.preprocessed = ft_resampledata(cfg,Day1Res.preprocessed);
    Day2Res.preprocessed = ft_resampledata(cfg,Day2Res.preprocessed);

    if cue_first==1
        cfg = [];
        cfg.latency = [-0.2, 4];
        Day1Res.preprocessed = ft_selectdata(cfg, Day1Res.preprocessed);
        Day2Res.preprocessed = ft_selectdata(cfg, Day2Res.preprocessed);
    else
        cfg = [];
        cfg.latency = [-3.2, 2];
        Day1Res.preprocessed = ft_selectdata(cfg, Day1Res.preprocessed);
        Day2Res.preprocessed = ft_selectdata(cfg, Day2Res.preprocessed);
    end


    Day1ResMat = [];
    for tr=1:length(Day1Res.preprocessed.trial)
        Day1ResMat(:,:,tr) = Day1Res.preprocessed.trial{tr};
    end

    Day2ResMat = [];
    for tr=1:length(Day2Res.preprocessed.trial)
        Day2ResMat(:,:,tr) = Day2Res.preprocessed.trial{tr};
    end


    all_res = cat(3,Day1ResMat,Day2ResMat);
    all_label = [Day1Res.preprocessed.trialinfo;Day2Res.preprocessed.trialinfo];

    idx = all_label(:,7)==0;

    all_res_sel = all_res(:,:,idx);
    all_label_sel = all_label(idx,3);

    %7-Missed;
    %8-Outcome;
    %9-Configuration;

    numFolds = 10;
    acc = zeros(size(all_res_sel,2), size(all_res_sel,2), numFolds);  % Preallocate accuracy matrix for temporal generalization

    % Stratified k-fold partitioning
    cv = cvpartition(all_label_sel, 'KFold', numFolds);

    for fold = 1:numFolds
        % Get training and testing indices
        trainSet_idx = find(training(cv, fold));
        testSet_idx = find(test(cv, fold));

        for train_time = 1:size(all_res_sel,2)
            % Train SVM model on the training set at a specific time point
            class_svm = fitcsvm(squeeze(all_res_sel(:,train_time,trainSet_idx))', all_label_sel(trainSet_idx));

            parfor test_time = 1:size(all_res_sel,2)
                % Predict on the testing set at another time point
                pred = predict(class_svm, squeeze(all_res_sel(:,test_time,testSet_idx))');

                % Calculate accuracy for the current fold and time point pair
                acc(train_time, test_time, fold) = sum(pred == all_label_sel(testSet_idx)) / length(pred);
            end
        end
        disp(['Finished Fold ', num2str(fold),' computation'])
    end
    
    if cue_first ==1
        save(['./Res_ClassContext/sbj',num2str(s),'_CueFirst'],'acc')
    else
        save(['./Res_ClassContext/sbj',num2str(s),'_StimFirst'],'acc')
    end
    %all_acc(:,:,:,s) = acc;
    %acc_sbj(:,:,s) = mean(acc,3);


end
