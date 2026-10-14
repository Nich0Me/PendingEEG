function [Results, TimeMat] = StimFirstTask(Timing, Sizes, TrialMat, EEG)
% Open the psychtoolbox window
[Win, rect]=Screen('OpenWindow',0, [127 127 127],[0 0 800 500]); % 

RefreshInterval = Screen('GetFlipInterval', Win);
a = KbName('a');
k = KbName('k');
RestrictKeysForKbCheck([a, k])
% What is the desired Refresh Rate (RR)
RR = Timing.RR;

% Check the refresh interval
if round(1/RefreshInterval)~=RR
    disp(round(1/RefreshInterval))
    %sca
    %error('Detected wrong Refresh Rate')
    disp('UNCOMMENT REFRESH RATE')
end

%Load Images
objIm = 'StimT.png';
TrLoad = imread(objIm);

objIm = 'StimS.png';
SqLoad = imread(objIm);

objIm = 'StimC.png';
CiLoad = imread(objIm);

objIm = 'StimSt.png';
StLoad = imread(objIm);

objIm = 'CueA.png';
CALoad = imread(objIm);

objIm = 'CueB.png';
CBLoad = imread(objIm);

commandwindow;

center_h = rect(3)/2;
center_v = rect(4)/2;

% Define the breaks
MakeABreak = Timing.MakeABreak;

% Define textsize
Screen('TextSize', Win, 60)
% Screen press to start and wait for kb
DrawFormattedText(Win,'Press to start','center','center', [0 0 0]);
% flip the screen and get the vbl
vbl = Screen('Flip', Win, .5*RefreshInterval);
KbWait;


tic
for trial_n = 1:size(TrialMat,1)

    if sum(trial_n == MakeABreak) == 1
        DrawFormattedText(Win,['Relax \n press a button to continue \n'],'center','center', [0 0 0]);
        vbl = Screen('Flip', Win, vbl+ .5*RefreshInterval);
        WaitSecs(1)
        KbWait
    end

    %% Fixation
    nIteration = 0;
    FixStart = GetSecs;
    while nIteration <= (Timing.Fixation+rand*0.1)*RR
        DrawFormattedText(Win,'+','center','center', [0 0 0]);
        vbl = Screen('Flip', Win, vbl+.5*RefreshInterval);
        nIteration = nIteration+1;
    end
    
    %% Stimulus
    StimStart = GetSecs;
    nIteration = 0;
    while nIteration <= Timing.Stimulus*RR
        if TrialMat(trial_n,2)==1
            Stim = Screen('MakeTexture', Win, TrLoad);
        elseif TrialMat(trial_n,2)==2
            Stim = Screen('MakeTexture', Win, SqLoad);
        elseif TrialMat(trial_n,2)==3
            Stim = Screen('MakeTexture', Win, CiLoad);
        elseif TrialMat(trial_n,2)==4
            Stim = Screen('MakeTexture', Win, StLoad);
        end
        
        Screen('DrawTexture', Win, Stim,[],[center_h-Sizes.StimDim/2, center_v-Sizes.StimDim/2, center_h+Sizes.StimDim/2, center_v+Sizes.StimDim/2]);
        vbl = Screen('Flip', Win, vbl+.5*RefreshInterval);
        
        nIteration = nIteration+1;
    end
    
    %% Context

    keyIsDown = 0;
    pressed = zeros(1,256);
    nIteration = 0;

    DecStart = GetSecs;
    while nIteration <= Timing.Cue*RR && keyIsDown == 0
        if TrialMat(trial_n,3)==1
            Cue = Screen('MakeTexture', Win, CALoad);
        elseif TrialMat(trial_n,3)==2
            Cue = Screen('MakeTexture', Win, CBLoad);
        end
        Screen('DrawTexture', Win, Cue,[],[center_h-Sizes.StimDim/2, center_v-Sizes.StimDim/2, center_h+Sizes.StimDim/2, center_v+Sizes.StimDim/2]);
        vbl = Screen('Flip', Win, vbl+.5*RefreshInterval);
        [keyIsDown, ~, pressed, ~] = KbCheck;
        nIteration = nIteration+1;
    end
    
    RT = GetSecs-DecStart;

    if strcmp(KbName(pressed), 'a')
        Action = 1;
    elseif strcmp(KbName(pressed), 'k')
        Action = 0;
    else
        Action = 2;
    end

    nIteration = 0;
    FeedStart = GetSecs;

    %% Feedback
    while nIteration <= Timing.Feedback*RR

        if Action == TrialMat(trial_n,4)
            feed = 1;
            if TrialMat(trial_n,)
            DrawFormattedText(Win,['100'],'center','center', [0 0 0]);
        elseif Action == 2
            feed = 0;
            DrawFormattedText(Win,['Too Late'],'center','center', [0 0 0]);
        else
            feed = 0;
            DrawFormattedText(Win,['Incorrect'],'center','center', [0 0 0]);
        end

        vbl = Screen('Flip', Win, vbl+ .5*RefreshInterval);
        nIteration = nIteration+1;
    end

    Results(trial_n).Action = Action;

    if Action == 2
        Results(trial_n).Missed = 1;
    else
        Results(trial_n).Missed = 0;
    end

    Results(trial_n).Outcome = TrialMat(trial_n,4);
    Results(trial_n).Trial_n = trial_n;
    Results(trial_n).Cue = [TrialMat(trial_n,3)];
    Results(trial_n).RT = RT;
    Results(trial_n).Feedback = feed;
    
    TrialEnd = GetSecs;
    TimeMat(trial_n,:) = [StimStart-FixStart, DecStart-StimStart, FeedStart-DecStart, TrialEnd-FeedStart];
    save(['Temp_',datestr(now,'ddmmhh')], 'Results','TimeMat')
end

sca
toc
end

