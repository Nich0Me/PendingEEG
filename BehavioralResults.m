%% Behavioral Figure

clear all
close all

cue_first =0;
data_folder = './Participants_BEH/';

for s = 1:30

    if cue_first == 1
        temp = dir(fullfile([data_folder,num2str(s),'_CueFirst_Day1','*']));
        load([data_folder,temp.name])
        Day1Res = Results;

        temp = dir(fullfile([data_folder,num2str(s),'_CueFirst_Day2','*']));
        load([data_folder,temp.name])
        Day2Res = Results;

    else
        temp = dir(fullfile([data_folder,num2str(s),'_StimFirst_Day1','*']));
        load([data_folder,temp.name])
        Day1Res = Results;

        temp = dir(fullfile([data_folder,num2str(s),'_StimFirst_Day2','*']));
        load([data_folder,temp.name])
        Day2Res = Results;
    end

    %% Preprocess Data
    idx_missed = find([Day1Res.Missed] == 1 | [Day1Res.RT] <0.15);
    Day1Res(idx_missed) = [];

    idx_missed = find([Day2Res.Missed] == 1 | [Day2Res.RT] <0.15);
    Day2Res(idx_missed) = [];

    %% General Accuracy/RT
    AccDay1(s) = mean([Day1Res.Feedback]);
    AccDay2(s) = mean([Day2Res.Feedback]);

    RTDay1(s) = mean([Day1Res.RT]);
    RTDay2(s) = mean([Day2Res.RT]);

    %% Learning Curve
    idxb1 = find([Day1Res.Trial_n] > 0 & [Day1Res.Trial_n] < 51);
    idxb2 = find([Day1Res.Trial_n] > 50 & [Day1Res.Trial_n] < 101);
    idxb3 = find([Day1Res.Trial_n] > 100 & [Day1Res.Trial_n] < 151);
    idxb4 = find([Day1Res.Trial_n] > 150 & [Day1Res.Trial_n] < 201);

    AcDa1B1(s) = mean([Day1Res(idxb1).Feedback]);
    AcDa1B2(s) = mean([Day1Res(idxb2).Feedback]);
    AcDa1B3(s) = mean([Day1Res(idxb3).Feedback]);
    AcDa1B4(s) = mean([Day1Res(idxb4).Feedback]);

    RtDa1B1(s) = mean([Day1Res(idxb1).RT]);
    RtDa1B2(s) = mean([Day1Res(idxb2).RT]);
    RtDa1B3(s) = mean([Day1Res(idxb3).RT]);
    RtDa1B4(s) = mean([Day1Res(idxb4).RT]);

    idxb1 = find([Day2Res.Trial_n] > 0 & [Day2Res.Trial_n] < 61);
    idxb2 = find([Day2Res.Trial_n] > 60 & [Day2Res.Trial_n] < 121);
    idxb3 = find([Day2Res.Trial_n] > 120 & [Day2Res.Trial_n] < 181);
    idxb4 = find([Day2Res.Trial_n] > 180 & [Day2Res.Trial_n] < 241);

    AcDa2B1(s) = mean([Day2Res(idxb1).Feedback]);
    AcDa2B2(s) = mean([Day2Res(idxb2).Feedback]);
    AcDa2B3(s) = mean([Day2Res(idxb3).Feedback]);
    AcDa2B4(s) = mean([Day2Res(idxb4).Feedback]);

    RtDa2B1(s) = mean([Day2Res(idxb1).RT]);
    RtDa2B2(s) = mean([Day2Res(idxb2).RT]);
    RtDa2B3(s) = mean([Day2Res(idxb3).RT]);
    RtDa2B4(s) = mean([Day2Res(idxb4).RT]);

 
    %% Accuracy/RT per planet
    idxPlan1 = [Day1Res.Cue] == 1;
    idxPlan2 = [Day1Res.Cue] == 2;

    AcDa1Cu1(s) = mean([Day1Res(idxPlan1).Feedback]);
    AcDa1Cu2(s) = mean([Day1Res(idxPlan2).Feedback]);
    RtDa1Cu1(s) = mean([Day1Res(idxPlan1).RT]);
    RtDa1Cu2(s) = mean([Day1Res(idxPlan2).RT]);

    idxPlan1 = [Day2Res.Cue] == 1;
    idxPlan2 = [Day2Res.Cue] == 2;

    AcDa2Cu1(s) = mean([Day2Res(idxPlan1).Feedback]);
    AcDa2Cu2(s) = mean([Day2Res(idxPlan2).Feedback]);
    RtDa2Cu1(s) = mean([Day2Res(idxPlan1).RT]);
    RtDa2Cu2(s) = mean([Day2Res(idxPlan2).RT]);

    %% Accuracy/RT for same response compared to different responses

    idxsame = find([Day1Res.Configuration]==1 | [Day1Res.Configuration] == 4);
    idxdiff = find([Day1Res.Configuration]==2 | [Day1Res.Configuration] == 3);

    AcDa1Sa(s) = mean([Day1Res(idxsame).Feedback]);
    AcDa1Df(s) = mean([Day1Res(idxdiff).Feedback]);
    RtDa1Sa(s) = mean([Day1Res(idxsame).RT]);
    RtDa1Df(s) = mean([Day1Res(idxdiff).RT]);

    idxsame = find([Day2Res.Configuration]==1 | [Day2Res.Configuration] == 4);
    idxdiff = find([Day2Res.Configuration]==2 | [Day2Res.Configuration] == 3);

    AcDa2Sa(s) = mean([Day2Res(idxsame).Feedback]);
    AcDa2Df(s) = mean([Day2Res(idxdiff).Feedback]);
    RtDa2Sa(s) = mean([Day2Res(idxsame).RT]);
    RtDa2Df(s) = mean([Day2Res(idxdiff).RT]);
end

%% Average Accuracy
figure
bar([mean(AccDay1),mean(AccDay2)])
hold on
errorbar([mean(AccDay1),mean(AccDay2)],[std(AccDay1),std(AccDay2)]./sqrt(length(AccDay1)),'k-')
ylim([0.5,1])
plot(ones(length(AccDay1),1)*1.1, AccDay1,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay2),1)*2.1, AccDay2,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:2, 'XTickLabels', {'Day 1','Day 2'})
title('Average Accuracy')

%% Average RT
figure
bar([mean(RTDay1),mean(RTDay2)])
hold on
errorbar([mean(RTDay1),mean(RTDay2)],[std(RTDay1),std(RTDay2)]./sqrt(length(RTDay1)),'k-')
plot(ones(length(RTDay1),1)*1.1, RTDay1,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(RTDay2),1)*2.1, RTDay2,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:2, 'XTickLabels', {'Day 1','Day 2'})
title('Average RT')

%% Accuracy per block
figure
subplot(1,2,1)
bar([mean(AcDa1B1),mean(AcDa1B2),mean(AcDa1B3),mean(AcDa1B4)])
hold on
errorbar([mean(AcDa1B1),mean(AcDa1B2),mean(AcDa1B3),mean(AcDa1B4)],[std(AcDa1B1),std(AcDa1B2),std(AcDa1B3),std(AcDa1B4)]./sqrt(length(AccDay1)),'k-')
ylim([0.35,1])
plot(ones(length(AccDay1),1)*1.1, AcDa1B1,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay2),1)*2.1, AcDa1B2,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay1),1)*3.1, AcDa1B3,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay2),1)*4.1, AcDa1B4,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:4, 'XTickLabels', {'Block 1','Block 2','Block 3','Block 4'})
title('Accuracy per block Day 1')

subplot(1,2,2)
bar([mean(AcDa2B1),mean(AcDa2B2),mean(AcDa2B3),mean(AcDa2B4)])
hold on
errorbar([mean(AcDa2B1),mean(AcDa2B2),mean(AcDa2B3),mean(AcDa2B4)],[std(AcDa2B1),std(AcDa2B2),std(AcDa2B3),std(AcDa2B4)]./sqrt(length(AccDay1)),'k-')
ylim([0.35,1])
plot(ones(length(AccDay1),1)*1.1, AcDa2B1,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay2),1)*2.1, AcDa2B2,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay1),1)*3.1, AcDa2B3,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay2),1)*4.1, AcDa2B4,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:4, 'XTickLabels', {'Block 1','Block 2','Block 3','Block 4'})
title('Accuracy per block Day 2')
sgtitle('Accuracy per block')

%% RT per block
figure
subplot(1,2,1)
bar([mean(RtDa1B1),mean(RtDa1B2),mean(RtDa1B3),mean(RtDa1B4)])
hold on
errorbar([mean(RtDa1B1),mean(RtDa1B2),mean(RtDa1B3),mean(RtDa1B4)],[std(RtDa1B1),std(RtDa1B2),std(RtDa1B3),std(RtDa1B4)]./sqrt(length(AccDay1)),'k-')
ylim([0.15,1.6])
plot(ones(length(AccDay1),1)*1.1, RtDa1B1,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay2),1)*2.1, RtDa1B2,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay1),1)*3.1, RtDa1B3,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay2),1)*4.1, RtDa1B4,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:4, 'XTickLabels', {'Block 1','Block 2','Block 3','Block 4'})
title('RT per block Day 1')

subplot(1,2,2)
bar([mean(RtDa2B1),mean(RtDa2B2),mean(RtDa2B3),mean(RtDa2B4)])
hold on
errorbar([mean(RtDa2B1),mean(RtDa2B2),mean(RtDa2B3),mean(RtDa2B4)],[std(RtDa2B1),std(RtDa2B2),std(RtDa2B3),std(RtDa2B4)]./sqrt(length(AccDay1)),'k-')
ylim([0.15,1.6])
plot(ones(length(AccDay1),1)*1.1, RtDa2B1,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay2),1)*2.1, RtDa2B2,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay1),1)*3.1, RtDa2B3,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(AccDay2),1)*4.1, RtDa2B4,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:4, 'XTickLabels', {'Block 1','Block 2','Block 3','Block 4'})
title('RT per block Day 2')

sgtitle('RT per block')

%% Average Acc Planet
figure
subplot(1,2,1)
bar([mean(AcDa1Cu1),mean(AcDa1Cu2)])
ylim([0.5,1])
hold on
errorbar([mean(AcDa1Cu1),mean(AcDa1Cu2)],[std(AcDa1Cu1),std(AcDa1Cu2)]./sqrt(length(RTDay1)),'k-')
plot(ones(length(RTDay1),1)*1.1, AcDa1Cu1,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(RTDay2),1)*2.1, AcDa1Cu2,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:2, 'XTickLabels', {'Cue 1','Cue 2'})
title('Average Acc per Cue')

subplot(1,2,2)
bar([mean(AcDa2Cu1),mean(AcDa2Cu2)])
ylim([0.5,1])
hold on
errorbar([mean(AcDa2Cu1),mean(AcDa2Cu2)],[std(AcDa2Cu1),std(AcDa2Cu2)]./sqrt(length(RTDay1)),'k-')
plot(ones(length(RTDay1),1)*1.1, AcDa2Cu1,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(RTDay2),1)*2.1, AcDa2Cu2,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:2, 'XTickLabels', {'Cue 1','Cue 2'})
title('Average Acc per Cue')
sgtitle('Accuracy per planet')

%% RT per planet
figure
subplot(1,2,1)
bar([mean(RtDa1Cu1),mean(RtDa1Cu2)])
hold on
errorbar([mean(RtDa1Cu1),mean(RtDa1Cu2)],[std(RtDa1Cu1),std(RtDa1Cu2)]./sqrt(length(RTDay1)),'k-')
plot(ones(length(RTDay1),1)*1.1, RtDa1Cu1,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(RTDay2),1)*2.1, RtDa1Cu2,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:2, 'XTickLabels', {'Cue 1','Cue 2'})
title('Average RT per Cue')

subplot(1,2,2)
bar([mean(RtDa2Cu1),mean(RtDa2Cu2)])
hold on
errorbar([mean(RtDa2Cu1),mean(RtDa2Cu2)],[std(RtDa2Cu1),std(RtDa2Cu2)]./sqrt(length(RTDay1)),'k-')
plot(ones(length(RTDay1),1)*1.1, RtDa2Cu1,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(RTDay2),1)*2.1, RtDa2Cu2,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:2, 'XTickLabels', {'Cue 1','Cue 2'})
title('Average RT per Cue')
sgtitle('RT per planet')

%% Accuracy per same or different response

figure
subplot(1,2,1)
bar([mean(AcDa1Sa),mean(AcDa1Df)])
ylim([0.5,1])
hold on
errorbar([mean(AcDa1Sa),mean(AcDa1Df)],[std(AcDa1Sa),std(AcDa1Df)]./sqrt(length(RTDay1)),'k-')
plot(ones(length(RTDay1),1)*1.1, AcDa1Sa,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(RTDay2),1)*2.1, AcDa1Df,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:2, 'XTickLabels', {'Same','Different'})
title('Average Acc per response similarity Day 1')

subplot(1,2,2)
bar([mean(AcDa2Sa),mean(AcDa2Df)])
ylim([0.5,1])
hold on
errorbar([mean(AcDa2Sa),mean(AcDa2Df)],[std(AcDa2Sa),std(AcDa2Df)]./sqrt(length(RTDay1)),'k-')
plot(ones(length(RTDay1),1)*1.1, AcDa2Sa,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(RTDay2),1)*2.1, AcDa2Df,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:2, 'XTickLabels', {'Cue 1','Cue 2'})
title('Average Acc per response similarity day 2')
sgtitle('Average Acc per response similarity')

%% RT per same or different response

figure
subplot(1,2,1)
bar([mean(RtDa1Sa),mean(RtDa1Df)])
hold on
errorbar([mean(RtDa1Sa),mean(RtDa1Df)],[std(RtDa1Sa),std(RtDa1Df)]./sqrt(length(RTDay1)),'k-')
plot(ones(length(RTDay1),1)*1.1, RtDa1Sa,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(RTDay2),1)*2.1, RtDa1Df,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:2, 'XTickLabels', {'Same','Different'})
title('Average RT per response similarity Day 1')

subplot(1,2,2)
bar([mean(RtDa2Sa),mean(RtDa2Df)])
hold on
errorbar([mean(RtDa2Sa),mean(RtDa2Df)],[std(RtDa2Sa),std(RtDa2Df)]./sqrt(length(RTDay1)),'k-')
plot(ones(length(RTDay1),1)*1.1, RtDa2Sa,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
plot(ones(length(RTDay2),1)*2.1, RtDa2Df,'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor','k')
set(gca, 'XTick', 1:2, 'XTickLabels', {'Same','Different'})
title('Average RT per response similarity day 2')
sgtitle('Average RT per response similarity')
