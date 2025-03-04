% Wrangle data into what we want
spikes = readtable('E:\NeuralData\Extracted Data\spikeTimes.csv');
% Set parameters
OGfs = 24414.0625;
ISI = 0.4;
Window = 5.5;
durationBuffer = 0.1;
toneDuration = 0.05;
binWidth = 0.01;
freqPool=round(120*(2^(1/3)).^[0:20-1]);

lambda = 0.1; % firing rate per bin



% Just look at SUs for now
% spikes = spikes(spikes.Cluster == 1,:);

% Write in code to check if you've already done it to save time.
% mdlTBL = [];




ferrets = unique(spikes.Ferret)';
ferrets = sort(ferrets,'descend'); % Just to start from ,more important
for currFerret = 2001 % ferrets
    currSpikes = spikes(spikes.Ferret == currFerret,:);
    blocks = unique(currSpikes.Block)';
    for b = 540 % blocks
        %         if ~isempty(mdlTBL)
        %             if ~isempty(find(mdlTBL.Ferret == currFerret & mdlTBL.Block == b))
        %                 continue
        %             end
        %         end
        currSpikes2 = currSpikes(currSpikes.Block == b,:);
        file = dir(['E:\NeuralData\Extracted Data\F',num2str(currFerret),'*\LFP_F',num2str(currFerret),'*BlockWE-',num2str(b),'.mat']);
        if isempty(file)
            continue
        end
        load(fullfile(file.folder,file.name))
        disp(bHvData.filename)
        if contains(bHvData.filename,'FRA')||contains(bHvData.filename,'Noise')
            continue
        end
        
        % Load in behav data
        spikeStartSamples =  ceil((bHvData.StartSamples/2) + (durationBuffer*OGfs));
        [stimTable] = StimRef.getWARPTrialInfo(bHvData);
        [bHvTable] = Behav.getBehavTrialInfo(currFerret,b);
        count = 1;
        
        kaja = [];
        
        % Just trying with one block for now and one channel.
        % Under the assumption each trial is an observation
        nTrials = numel(spikeStartSamples); % total number of trials
        
        % preallocate structure in memory
        trial = struct();
        
        % Do 400ms eather side.
        % Currently doing it on both su and mu data
        kTrial = 1;
        for c = 21%1:unique(currSpikes2.Channel)
            currSpikes3 = currSpikes2(currSpikes2.Channel == c,:);
            spikeRate = Plot.PSTH(currSpikes3.SpikeTimes,spikeStartSamples,1:numel(spikeStartSamples),0.4,5.5,c,dataInfo,binWidth,1);
            avFR = mean(spikeRate,'all');
            
            % Check if channel has firing rate of greater than 0.5Hz
            if avFR < 0.5
                continue
            end
            [CF] = getBFfromRAND(currSpikes3,stimTable,spikeStartSamples,dataInfo,c);
            for n = 1:numel(spikeStartSamples)
                
                % Skip excluded trials or correction trials
                if ismember(dataInfo.excludedTrials{c,1},n) || bHvTable.CorrectionTrial(n) == 1
                    continue
                end
                stimFreqs = stimTable(n,9:end);
                stimFreqs = stimFreqs(~isnan(stimFreqs));
                
                % Convert stimFreqs into index
                [LIA,stimFreqIdx] = ismember(round(stimFreqs),freqPool);
                begWindow = spikeStartSamples(n) - (0.4*OGfs);
                endWindow = spikeStartSamples(n) + (((numel(stimFreqs)*0.05)+0.4)*OGfs);
%                 Pillow DM parameters
%                 spike train - currently keeping empty ones in but might
%                 notbe able to do that
                STrain = (currSpikes3.SpikeTimes(currSpikes3.SpikeTimes >= begWindow & currSpikes3.SpikeTimes < endWindow)-spikeStartSamples(n))/OGfs;
                % Currently combining MU and SU so want to sort the spike
                % time into 1 (get rid if splitting by cluster)
                STrain = sort(((STrain+0.4)*1000));
                
                trial(kTrial).sptrain           =  STrain;              
                trial(kTrial).duration          = 800 + numel(stimFreqs)*50;
                trial(kTrial).stimOn            = 400;
                trial(kTrial).stimOff           = trial(kTrial).stimOn + (numel(stimFreqs)*50);
                % Pretty surethe end of the transition time is at2000 even
                % though behaviour say 1950 :/
                trial(kTrial).REG               = bHvTable.Side(n);
                if trial(kTrial).REG == 0
                    trial(kTrial).transitionTime  = NaN;
                else
                    trial(kTrial).transitionTime    = (bHvTable.transitionTime(n)*1000)+50 + trial(kTrial).stimOn ;
                end
                trial(kTrial).CF                = find(round(CF)==freqPool);
                trial(kTrial).freqIdx           = [zeros(1,400) repelem(stimFreqIdx,50) zeros(1,400)];
                trial(kTrial).PL                = bHvTable.patternLength(n);
                trial(kTrial).Correct           = bHvTable.Correct(n);
                trial(kTrial).RespTime          = bHvTable.RespTime(n);
                
                kTrial = kTrial+1;
            end
            kaja = [];
            
            
        end
        save('KP_exampleData.mat', 'nTrials', 'trial', 'param')
        
        
    end
end
params.ferret = 2001;
params.ca
% Run the glm
expt = buildGLM.initExperiment('ms', 1, [], params);







function [CF] = getBFfromRAND(currentSpikes,stimTable,spikeStartSamples,dataInfo,channel)
freqPool=round(120*(2^(1/3)).^[0:20-1]);
binWidth = 0.01;
toneDuration = 0.05;
ISI = 0.4;
% Calculate the BF %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Only looking at RAND Trials
trials = unique(stimTable(stimTable(:,8)==0,7))';
FRAresp = NaN(numel(trials),numel(freqPool));
for i = 1:numel(trials)
    freqlist = stimTable(stimTable(:,7) == trials(i),9:end);
    freqlist = freqlist(1,~isnan(freqlist(1,:)));
    spikeRate = Plot.zscorePSTH(currentSpikes.SpikeTimes,spikeStartSamples,find(stimTable(:,7)==trials(i)),0.4,5.5,channel,dataInfo,binWidth,1);
    if isnan(spikeRate) & numel(spikeRate) == 1
        continue
    end
    % Remove ISI portion and first 8 tones to avoid any onset response
    spikeRate(:,1:(ISI+ISI)/binWidth) = [];
    freqlist(1:ISI/toneDuration) = [];
    % Remove last two tones to avoid offset
    freqlist(end-1:end) = [];
    freqs = unique(freqlist);
    
    bins = toneDuration/binWidth;
    y = [];
    % Going through each tone in the freqlist bin the psth
    for f = 1:numel(freqlist)
        y(:,f) = mean(spikeRate(:,(f-1)*bins+1:f*bins-1)');
    end
    % Go through each unique frequency and look for the
    % corresponiding palce in the freqlist nad pick out the
    % binned mean and mean it
    for f = freqs
        idx = find(f == freqlist);
        FRAresp(i,round(f)==freqPool) = mean(reshape(y(:,idx),[numel(y(:,idx)) 1]));
    end
end
meanFRAresp = nanmean(FRAresp);

[t,i] = max(meanFRAresp);
CF = freqPool(i);

end