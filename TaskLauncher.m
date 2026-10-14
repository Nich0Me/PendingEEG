%% Prepare what needed for the experiment
clear
close all

subject = input('Subject Number', 's');

Task = input('Task Number?');
Day = input('Day?');

Timing.RR = 60;
Timing.Fixation = 1;
Timing.Empty = 0.5;

if Task == 1
    Timing.Cue = 1.5;
    Timing.Stimulus = 3;
elseif Task == 2
    Timing.Cue = 3;
    Timing.Stimulus = 3;
end

Timing.Feedback = 1.5;
Sizes.StimDim = 300;

if Day == 1
    Timing.MakeABreak = 101:101:200;

    TrialMat = zeros(200,5);
    TrialMat(:,1) = 1:200;
    
    temp_Conf1=repmat([1,2,3,4]',[25,1]);
    temp_Cue1=repmat([1,1,1,1]',[25,1]);
    temp_Out1=repmat([1,0,1,0]',[25,1]);
    
    temp_Conf2=repmat([1,2,3,4]',[25,1]);
    temp_Cue2=repmat([2,2,2,2]',[25,1]);
    temp_Out2=repmat([1,1,0,0]',[25,1]);

    temp_Conf = [temp_Conf1;temp_Conf2];
    temp_Cue = [temp_Cue1;temp_Cue2];
    temp_Out = [temp_Out1;temp_Out2];

    ordered = Shuffle(Shuffle(Shuffle(1:200)))';

    TrialMat(:,2) = temp_Conf(ordered);
    TrialMat(:,3) = temp_Cue(ordered);
    TrialMat(:,4) = temp_Out(ordered);

elseif Day == 2
    
    Timing.MakeABreak = 61:60:240;

    TrialMat = zeros(240,5);
    TrialMat(:,1) = 1:240;
    
    temp_Conf1=repmat([1,2,3,4]',[30,1]);
    temp_Cue1=repmat([1,1,1,1]',[30,1]);
    temp_Out1=repmat([1,0,1,0]',[30,1]);
    
    temp_Conf2=repmat([1,2,3,4]',[30,1]);
    temp_Cue2=repmat([2,2,2,2]',[30,1]);
    temp_Out2=repmat([1,1,0,0]',[30,1]);

    temp_Conf = [temp_Conf1;temp_Conf2];
    temp_Cue = [temp_Cue1;temp_Cue2];
    temp_Out = [temp_Out1;temp_Out2];

    ordered = Shuffle(Shuffle(Shuffle(1:240)))';

    TrialMat(:,2) = temp_Conf(ordered);
    TrialMat(:,3) = temp_Cue(ordered);
    TrialMat(:,4) = temp_Out(ordered);
end

EEG = 0;
%TrialMat = TrialMat(1:10,:);
if Task == 1
    [Results, TimeMat] = CueFirstTask(Timing, Sizes, TrialMat, EEG);
    save(['./Participants/',subject, '_CueFirst_',datestr(now,'HHMMSS')], 'Results','TimeMat')
elseif Task == 2
    [Results, TimeMat] = StimFirstTask(Timing, Sizes, TrialMat, EEG);
    save(['./Participants/',subject,'_StimFirst_',datestr(now,'HHMMSS')], 'Results','TimeMat')
end

