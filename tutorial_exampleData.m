%% Generate example (raw) dataset for the tutorial

% REQUIRES stat toolbox for poissnrnd

nTrials = 100; % total number of trials

% preallocate structure in memory
trial = struct();
trial(nTrials).duration = 0; % preallocate

lambda = 0.1; % firing rate per bin

for kTrial = 1:nTrials
    duration = 150 + ceil(rand * 200);
    % Duration of the trial (in ms)
    trial(kTrial).duration = duration;
    % The LFP
    trial(kTrial).LFP = cumsum(randn(duration, 1));
    % The continuous X and Y position of the eye position
    trial(kTrial).eyepos = cumsum(randn(duration, 2));
    % The time in ms at which the dots were on
    trial(kTrial).dotson = ceil(rand * (duration - 100));
    % The time in ms at which the dots were off
    trial(kTrial).dotsoff = trial(kTrial).dotson + ceil(rand * 10);
    % Time where there was a saccad
    trial(kTrial).saccade = 100 + ceil(rand * (duration - 100));
    trial(kTrial).coh = sign(rand - 0.5) * 2^ceil(rand*8);
    % Choice as a binary
    trial(kTrial).choice = round(rand);
    % spike train
    trial(kTrial).sptrain = sort(rand(poissrnd(lambda * 0.9 * duration), 1) * duration);
    
    trial(kTrial).sptrain2 = sort(rand(poissrnd(0.1 * lambda * duration), 1) * duration);

    trial(kTrial).sptrain = sort([trial(kTrial).sptrain; trial(kTrial).sptrain2 + 2]);
    trial(kTrial).sptrain(trial(kTrial).sptrain > trial(kTrial).duration) = [];

    trial(kTrial).meta = rand;
end

param.samplingFreq = 1; % kHz
param.monkey = 'F99';

save('exampleData.mat', 'nTrials', 'trial', 'param')
