function layers = hCreatePartialNetwork()
% Function that creates partial layer 
% Copyright 2024 The MathWorks, Inc.

layers = [
  reluLayer
  convolution1dLayer(8, 16,"Name","conv1d_2")
  reluLayer
  globalMaxPooling1dLayer
  fullyConnectedLayer(6)
  softmaxLayer];