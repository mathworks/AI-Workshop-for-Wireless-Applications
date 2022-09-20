function [trainData,trainLabels, valData, valLabels] = hGenerateTrainingData(dataSize)
% Generate training data examples for channel estimation. Run dataSize
% number of iterations to create random channel configurations and pass an
% OFDM-modulated fixed resource grid with only the DM-RS symbols inserted.
% Perform perfect timing synchronization and OFDM demodulation, extracting
% the pilot symbols and performing linear interpolation at each iteration.
% Use perfect channel information to create the label data. The function
% returns 4 arrays - the training data and labels as well validation data
% and labels.
% Copyright 2022 The MathWorks, Inc.

% Set the random seed for reproducibility (this has no effect if a GPU is
% used)
rng('default')

fprintf('Starting data generation...\n')

% List of possible channel profiles
delayProfiles = {'TDL-A', 'TDL-B', 'TDL-C', 'TDL-D', 'TDL-E'};

simParameters = hDeepLearningChanEstSimParameters();
carrier = simParameters.Carrier;
pdsch = simParameters.PDSCH;

% Create the channel model object
nTxAnts = simParameters.NTxAnts;
nRxAnts = simParameters.NRxAnts;

channel = nrTDLChannel; % TDL channel object
channel.NumTransmitAntennas = nTxAnts;
channel.NumReceiveAntennas = nRxAnts;

% Use the value returned from nrOFDMInfo to
% set the channel model sample rate
waveformInfo = nrOFDMInfo(carrier);
channel.SampleRate = waveformInfo.SampleRate;

% Get the maximum number of delayed samples by a channel multipath
% component. This number is calculated from the channel path with the largest
% delay and the implementation delay of the channel filter, and is required
% to flush the channel filter to obtain the received signal.
chInfo = info(channel);
maxChDelay = ceil(max(chInfo.PathDelays*channel.SampleRate)) + chInfo.ChannelFilterDelay;

% Return DM-RS indices and symbols
dmrsSymbols = nrPDSCHDMRS(carrier,pdsch);
dmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch);

% Create resource grid
grid = nrResourceGrid(carrier,nTxAnts);

% PDSCH DM-RS precoding and mapping
[~,dmrsAntIndices] = nrExtractResources(dmrsIndices,grid);
grid(dmrsAntIndices) = dmrsSymbols;

% OFDM modulation of associated resource elements
txWaveform_original = nrOFDMModulate(carrier,grid);

% Acquire linear interpolator coordinates for neural net preprocessing
[rows,cols] = find(grid ~= 0);
dmrsSubs = [rows, cols, ones(size(cols))];
hest = zeros(size(grid));
[l_hest,k_hest] = meshgrid(1:size(hest,2),1:size(hest,1));

% Preallocate memory for the training data and labels
numExamples = dataSize;
[trainData, trainLabels] = deal(zeros([612 14 2 numExamples]));

% Main loop for data generation, iterating over the number of examples
% specified in the function call. Each iteration of the loop produces a
% new channel realization with a random delay spread, doppler shift,
% and delay profile. Every perturbed version of the transmitted
% waveform with the DM-RS symbols is stored in trainData, and the
% perfect channel realization in trainLabels.
for i = 1:numExamples
    % Release the channel to change nontunable properties
    channel.release

    % Pick a random seed to create different channel realizations
    channel.Seed = randi([1001 2000]);

    % Pick a random delay profile, delay spread, and maximum doppler shift
    channel.DelayProfile = string(delayProfiles(randi([1 numel(delayProfiles)])));
    channel.DelaySpread = randi([1 300])*1e-9;
    channel.MaximumDopplerShift = randi([5 400]);

    % Send data through the channel model. Append zeros at the end of
    % the transmitted waveform to flush channel content. These zeros
    % take into account any delay introduced in the channel, such as
    % multipath delay and implementation delay. This value depends on
    % the sampling rate, delay profile, and delay spread
    txWaveform = [txWaveform_original; zeros(maxChDelay, size(txWaveform_original,2))];
    [rxWaveform,pathGains,sampleTimes] = channel(txWaveform);

    % Add additive white Gaussian noise (AWGN) to the received time-domain
    % waveform. To take into account sampling rate, normalize the noise power.
    % The SNR is defined per RE for each receive antenna (3GPP TS 38.101-4).
    SNRdB = randi([0 10]);  % Random SNR values between 0 and 10 dB
    SNR = 10^(SNRdB/10);    % Calculate linear SNR
    N0 = 1/sqrt(2.0*nRxAnts*double(waveformInfo.Nfft)*SNR);
    noise = N0*complex(randn(size(rxWaveform)),randn(size(rxWaveform)));
    rxWaveform = rxWaveform + noise;

    % Perfect synchronization. Use information provided by the channel
    % to find the strongest multipath component
    pathFilters = getPathFilters(channel); % Get path filters for perfect channel estimation
    [offset,~] = nrPerfectTimingEstimate(pathGains,pathFilters);

    rxWaveform = rxWaveform(1+offset:end, :);

    % Perform OFDM demodulation on the received data to recreate the
    % resource grid, including padding in case practical
    % synchronization results in an incomplete slot being demodulated
    rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
    [K,L,R] = size(rxGrid);
    if (L < carrier.SymbolsPerSlot)
        rxGrid = cat(2,rxGrid,zeros(K,carrier.SymbolsPerSlot-L,R));
    end

    % Perfect channel estimation, using the value of the path gains
    % provided by the channel. This channel estimate does not
    % include the effect of transmitter precoding
    estChannelGridPerfect = nrPerfectChannelEstimate(carrier,pathGains, ...
        pathFilters,offset,sampleTimes);

    % Linear interpolation
    dmrsRx = rxGrid(dmrsIndices);
    dmrsEsts = dmrsRx .* conj(dmrsSymbols);
    f = scatteredInterpolant(dmrsSubs(:,2),dmrsSubs(:,1),dmrsEsts);
    hest = f(l_hest,k_hest);

    % Split interpolated grid into real and imaginary components and
    % concatenate them along the third dimension, as well as for the
    % true channel response
    rx_grid = cat(3, real(hest), imag(hest));
    est_grid = cat(3, real(estChannelGridPerfect), ...
        imag(estChannelGridPerfect));

    % Add generated training example and label to the respective arrays
    trainData(:,:,:,i) = rx_grid;
    trainLabels(:,:,:,i) = est_grid;

    % Data generation tracker
    if mod(i,round(numExamples/8)) == 0
        fprintf('%3.2f%% complete\n',i/numExamples*100);
    end
end

% Set the number of examples for validation data
valSize = 56; 

% Split into training and validation sets
valData = trainData(:,:,:,1:valSize);
valLabels = trainLabels(:,:,:,1:valSize);

trainData = trainData(:,:,:,valSize+1:end);
trainLabels = trainLabels(:,:,:,valSize+1:end);

fprintf('Data generation complete!\n')

end