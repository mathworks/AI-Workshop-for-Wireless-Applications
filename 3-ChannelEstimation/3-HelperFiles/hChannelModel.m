function [interpChannelGrid,estChannelGrid,estChannelGridPerfect] = hChannelModel()
% Function to Create and Simulate Channel Model 
% Copyright 2022 The MathWorks, Inc.

%% Create Channel Model
% Set the simulation noise level in dB
SNRdB = 10;

% Load the predefined simulation parameters, including the 
% PDSCH parameters and DM-RS configuration.
simParameters = hDeepLearningChanEstSimParameters();
carrier = simParameters.Carrier;
pdsch = simParameters.PDSCH;

% Create a TDL channel model and set channel parameters. 
% To compare different channel responses of the estimators, 
% you can change these parameters later.
channel = nrTDLChannel;
channel.Seed = 0;
channel.DelayProfile = 'TDL-A';
channel.DelaySpread = 3e-7;
channel.MaximumDopplerShift = 50;

% This example supports only SISO configuration
channel.NumTransmitAntennas = 1;
channel.NumReceiveAntennas = 1;

waveformInfo = nrOFDMInfo(carrier);
channel.SampleRate = waveformInfo.SampleRate;

% Get the maximum number of delayed samples by a channel multipath 
% component. This number is needed to flush the channel filter when 
% obtaining the received signal.
chInfo = info(channel);
maxChDelay = ceil(max(chInfo.PathDelays*channel.SampleRate))+chInfo.ChannelFilterDelay;

%% Simulate PDSCH DM-RS Transmission

% Generate DM-RS indices and symbols
dmrsSymbols = nrPDSCHDMRS(carrier,pdsch);
dmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch);

% Create resource grid
pdschGrid = nrResourceGrid(carrier);

% Map PDSCH DM-RS symbols to the grid
pdschGrid(dmrsIndices) = dmrsSymbols;

% OFDM-modulate associated resource elements
txWaveform = nrOFDMModulate(carrier,pdschGrid);

%To flush the channel content, append zeros at the end of the transmitted 
% waveform. These zeros take into account any delay introduced in 
% the channel, such as multipath and implementation delay. The number of 
% zeros depends on the sampling rate, delay profile, and delay spread.
txWaveform = [txWaveform; zeros(maxChDelay,size(txWaveform,2))];

% Send data through the TDL channel model. 
[rxWaveform,pathGains,sampleTimes] = channel(txWaveform);

% Add additive white Gaussian noise (AWGN) to the received time-domain 
% waveform. To take into account sampling rate, normalize the noise power. 
% The SNR is defined per resource element (RE) for each receive antenna
% (3GPP TS 38.101-4) 

SNR = 10^(SNRdB/10); % Calculate linear SNR
N0 = 1/sqrt(2.0*simParameters.NRxAnts*double(waveformInfo.Nfft)*SNR);
noise = N0*complex(randn(size(rxWaveform)),randn(size(rxWaveform)));
rxWaveform = rxWaveform + noise;

% Perform perfect synchronization. To find the strongest multipath 
% component, use the information provided by the channel.
% Get path filters for perfect channel estimation
pathFilters = getPathFilters(channel); 
[offset,~] = nrPerfectTimingEstimate(pathGains,pathFilters);

rxWaveform = rxWaveform(1+offset:end, :);

% OFDM-demodulate the received data to recreate the resource grid.
rxGrid = nrOFDMDemodulate(carrier,rxWaveform);

% Pad the grid with zeros in case an incomplete slot has been demodulated
[K,L,R] = size(rxGrid);
if (L < carrier.SymbolsPerSlot)
    rxGrid = cat(2,rxGrid,zeros(K,carrier.SymbolsPerSlot-L,R));
end

% Interpolate the received resource grid using pilot symbol locations
interpChannelGrid = hPreprocessInput(rxGrid,dmrsIndices,dmrsSymbols);

% Perform perfect channel estimation
estChannelGridPerfect = nrPerfectChannelEstimate(carrier,pathGains, ...
 pathFilters,offset,sampleTimes);

% Perform practical channel estimation
[estChannelGrid,~] = nrChannelEstimate(carrier,rxGrid,dmrsIndices, ...
 dmrsSymbols,'CDMLengths',pdsch.DMRS.CDMLengths);