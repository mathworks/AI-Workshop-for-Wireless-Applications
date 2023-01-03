function hPlotSpectogram(rxFrames,rxLabels)
% Function to plot Spectrogram
% rxFrames: Frames from different modulations 
% rxLabels: Modulation Type corresponding to each frame
%
% Copyright 2022 The MathWorks, Inc.

modulationTypes = categorical(["BPSK", "QPSK", "GFSK","PAM4","16QAM", "64QAM"]);

% Select a random frame to view 
idx = randi([1 size(rxFrames,1)/6]);

fs = 200e3; %Sampling Frequency 
sps = 8;    % Symbols per frame

figure
for modType=1:length(modulationTypes)

    % Select Modulation Type 
    allModFrames = rxFrames(rxLabels == modulationTypes(modType));

    % Select Subplot
    subplot(3, 2, modType);
    frame = allModFrames{idx};
    spf = size(frame,2);

    % Plot Spectrogram
    spectrogram(frame,kaiser(sps),0,spf,fs,'centered');
    title(string(modulationTypes(modType)));

end

% Remove Color Bar
h = gcf; delete(findall(h.Children, 'Type', 'ColorBar'))

end
