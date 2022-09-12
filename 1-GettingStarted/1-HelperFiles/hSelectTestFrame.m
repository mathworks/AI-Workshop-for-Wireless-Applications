function modFrame = hSelectTestFrame(rxFrames,rxLabels,modType)
% Plot Spectrogram of a frame

% hRandomFrame(rxFrames,rxLabels,modType) slects a frame from the 
% list rxFrames and plots a spectrogram

% Copyright 2022 The MathWorks, Inc.

% Select a random frame from the list
allModFrames = rxFrames(:,:,:,rxLabels == modType);
modFrame = allModFrames(:,:,:,randi([1 40]));

fs = 200e3;             % Sampling Frequency 
sps = 8;                % Symbols per frame
spf = size(modFrame,2); % Samples per frame

frame = complex(modFrame(:,:,1),modFrame(:,:,2));

% Plot Spectrogram
figure
spectrogram(frame,kaiser(sps),0,spf,fs,'centered');

h = gcf;
h.Position = [200 200 250 200];
title(string(modType));

end
