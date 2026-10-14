%%  fieldtrip preprocessing
clear all
close all

%addpath('./Functions')
addpath('/Users/menghi/Documents/MATLAB/Toolbox/fieldtrip-20220514')
addpath('/Users/menghi/Documents/MATLAB/Toolbox/refa8import_v1.3')
ft_defaults

%% PREPROCESSING

data_folder = './Participants_EEG/';
beh_data_folder = './Participants_BEH/';
cue_first = 0;
day = 2;

participant_number = 30;

if cue_first == 1
    data = read_refa8_data([data_folder,'sbj',num2str(participant_number),'_',num2str(day),'a','.hdr']);
    data_ev = read_refa8_event([data_folder,'sbj',num2str(participant_number),'_',num2str(day),'a','.hdr']);
    data_hdr = read_refa8_hdr([data_folder,'sbj',num2str(participant_number),'_',num2str(day),'a','.hdr']);
else
    data = read_refa8_data([data_folder,'sbj',num2str(participant_number),'_',num2str(day),'b','.hdr']);
    data_ev = read_refa8_event([data_folder,'sbj',num2str(participant_number),'_',num2str(day),'b','.hdr']);
    data_hdr = read_refa8_hdr([data_folder,'sbj',num2str(participant_number),'_',num2str(day),'b','.hdr']);
end

cfg = [];
cfg.hpfilter = 'yes';
cfg.hpfreq = 1;
%cfg.preproc.detrend = 'yes';
data = ft_preprocessing(cfg,data);

cfg = [];
cfg.reref = 'yes';
cfg.refchannel = {'eeg', '-A1', '-A2', '-TRIGGER', '-EOGH', '-EOGV'};
data = ft_preprocessing(cfg,data);

if cue_first == 1
    trl = [];
    trigger = 101;
    pre_stim = 1;
    post_stim = 4.5;
else
    trl = [];
    trigger = 101;
    pre_stim = 4;
    post_stim = 4;
end

for i = 1:length(data_ev)
    if double(data_ev(i).value) == trigger
    % Get the event sample and define pre- and post-stimulus times (in samples)
    begsample = data_ev(i).sample - round(pre_stim * data_hdr.Fs);  %  seconds before event
    endsample = data_ev(i).sample + round(post_stim * data_hdr.Fs);   %  second after event
    offset = -round(pre_stim * data_hdr.Fs);  % Offset to align stimulus onset

    % Skip invalid trials (e.g., if the segment would be out of bounds)
    if begsample < 1 || endsample > data_hdr.nSamples
        continue;
    end

    % Append to the trial definition matrix
    trl = [trl; begsample, endsample, offset, double(data_ev(i).value)];
    end
end


cfg = [];
cfg.trl = trl;
cfg.datafile = data_hdr.datafile;
cfg.headerfile = data_hdr.hdrfile;
cfg.fsample = data_hdr.Fs;
%cfg.channel = 'all';  % You can specify channels if needed

% Segment the data using FieldTrip's preprocessing function
segmented_data = ft_redefinetrial(cfg, data);

%% Load Behavioural Data
%load(fullfile(['./Data/ID',num2str(participant_number)],['sbj',num2str(participant_number),'.mat']))
if cue_first == 1
    temp = dir(fullfile([beh_data_folder,num2str(participant_number),'_CueFirst_Day',num2str(day),'*']));
    load([beh_data_folder,temp.name])
else
    temp = dir(fullfile([beh_data_folder,num2str(participant_number),'_StimFirst_Day',num2str(day),'*']));
    load([beh_data_folder,temp.name])
end

%% Add behavioural data
% Training
for t = 1:length(Results)
    segmented_data.trialinfo(t,2)= Results(t).Trial_n;
    segmented_data.trialinfo(t,3) = Results(t).Cue;
    segmented_data.trialinfo(t,4) = Results(t).Action;
    segmented_data.trialinfo(t,5) = Results(t).RT;
    segmented_data.trialinfo(t,6) = Results(t).Feedback;
    segmented_data.trialinfo(t,7) = Results(t).Missed;
    segmented_data.trialinfo(t,8) = Results(t).Outcome;
    segmented_data.trialinfo(t,9) = Results(t).Configuration;
end

%% Create Layout
cfg = [];
elec = ft_read_sens('easycap-M1.txt');
cfg.elec = elec;
layout = ft_prepare_layout(cfg, segmented_data);

%% visual inspection
cfg = [];
cfg.layout = layout;
cfg.viewmode = 'vertical';
cfg.ylim = [-20 20];
artfct = ft_databrowser(cfg,segmented_data);


%% Reject artifact
artfct.artfctdef.reject = 'complete';
artfct.artfctdef.feedback ='yes';

data_no_vis_artfct = ft_rejectartifact(artfct, segmented_data);

%% Prepare neighbours

% Prepare neighbours
cfg = [];
cfg.layout = layout;
cfg.method = 'triangulation';
neighbours = ft_prepare_neighbours(cfg, data_no_vis_artfct);


%% Channel look

% channel
cfg = [];
cfg.method = 'channel';
cfg.layout = layout;
cfg.keepchannel = 'repair';
cfg.neighbours = neighbours;
cfg.elec = elec;
data_interp_bad_chan = ft_rejectvisual(cfg, data_no_vis_artfct);

%% Interpolate Channel
cfg = [];
cfg.elec = elec;
cfg.badchannel = {'CPz'};
cfg.neighbours = neighbours;
data_interp_bad_chan = ft_channelrepair(cfg, data_no_vis_artfct);

%% summary
cfg = [];
cfg.method = 'summary';
data_interp_bad_end = ft_rejectvisual(cfg, data_interp_bad_chan);

%save([SubjFolder 'interpolated.mat'], 'data_interp_bad_end')

%% ICA
cfg = [];
cfg.method = 'fastica';
cfg.elec = elec;
cfg.channel = {'eeg', '-A1', '-A2', '-TRIGGER', '-EOGH', '-EOGV'};
cfg.layout = layout;
comp = ft_componentanalysis(cfg, data_interp_bad_end);

%% See Components
cfg = [];
cfg.layout = layout;
cfg.allowoverlap = 'yes';

ft_databrowser(cfg, comp);

%% Reject Components
cfg = [];
cfg.component = [3,4,5,1,14,15,22];
ica_rejected = ft_rejectcomponent(cfg, comp, data_interp_bad_end);

%% Final Filtering
cfg = [];
cfg.lpfilter = 'yes';
cfg.lpfreq = 100;
cfg.dftfilter = 'yes';
cfg.dftfreq = [50 100];
cfg.channel = {'eeg', '-A1', '-A2'};
preprocessed = ft_preprocessing(cfg, ica_rejected);

%% CHECK AVERAGE
cue1 = find(preprocessed.trialinfo(:,3) == 1);
cue2 = find(preprocessed.trialinfo(:,3) == 2);

cfg = [];
cfg.trials = cue1;
%cfg.keeptrials = 'yes';
cfg.channel = {'eeg', '-A1', '-A2'};
%cfg.latency = [-0.1,1.5];
Cue1 = ft_timelockanalysis(cfg, preprocessed);
figure
plot(Cue1.time,mean(Cue1.avg))

cfg.trials = cue2;
Cue2 = ft_timelockanalysis(cfg, preprocessed);
hold on
plot(Cue2.time,mean(Cue2.avg))


%% Look at the data
cfg = [];
cfg.layout = layout;
cfg.viewmode = 'vertical';
cfg.ylim = [-20 20];
cfg.allowoverlap = 'yes';
ft_databrowser(cfg,preprocessed);

%% Save
if cue_first == 1
    save(['./Preprocessed/sbj_',num2str(participant_number),'_Day',num2str(day),'-CuePreprocessed'], 'preprocessed','layout','neighbours')
else
    save(['./Preprocessed/sbj_',num2str(participant_number),'_Day',num2str(day),'-StimPreprocessed'], 'preprocessed','layout','neighbours')
end
