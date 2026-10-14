clear all
close all

ModelUncertainty = squareform([1,1,0,0,1,1]);

% Cue 1
% Conf 1 Action 1
% Conf 2 Action 0
% Conf 3 Action 1
% Conf 4 Action 0

ModelResponseT1 = squareform([1,0,1,1,0,1]);

% Cue
% Conf 1 Action 1
% Conf 2 Action 1
% Conf 3 Action 0
% Conf 4 Action 0

ModelResponseT2 = squareform([0,1,1,1,1,0]);

save('./RSA_Models/ModelsMats', 'ModelUncertainty','ModelResponseT1','ModelResponseT2')