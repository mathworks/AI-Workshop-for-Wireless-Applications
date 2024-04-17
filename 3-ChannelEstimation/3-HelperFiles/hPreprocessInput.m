function hest = hPreprocessInput(rxGrid,dmrsIndices,dmrsSymbols)
% Perform linear interpolation of the grid and input the result to the
% neural network This helper function extracts the DM-RS symbols from
% dmrsIndices locations in the received grid rxGrid and performs linear
% interpolation on the extracted pilots.
% Copyright 2024 The MathWorks, Inc.

% Obtain pilot symbol estimates
dmrsRx = rxGrid(dmrsIndices);
dmrsEsts = dmrsRx .* conj(dmrsSymbols);

% Create empty grids to fill after linear interpolation
[rxDMRSGrid, hest] = deal(zeros(size(rxGrid)));
rxDMRSGrid(dmrsIndices) = dmrsSymbols;

% Find the row and column coordinates for a given DMRS configuration
[rows,cols] = find(rxDMRSGrid ~= 0);
dmrsSubs = [rows,cols,ones(size(cols))];
[l_hest,k_hest] = meshgrid(1:size(hest,2),1:size(hest,1));

% Perform linear interpolation
f = scatteredInterpolant(dmrsSubs(:,2),dmrsSubs(:,1),dmrsEsts);
hest = f(l_hest,k_hest);

end

