function layers = hCreatePartialNetwork()
% Function that creates partial layer 
% Copyright 2022 The MathWorks, Inc.

layers = [
  batchNormalizationLayer
  reluLayer
  maxPooling2dLayer([1 2], 'Stride', [1 2])  
  fullyConnectedLayer(6)
  softmaxLayer];
end