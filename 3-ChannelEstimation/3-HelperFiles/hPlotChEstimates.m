function hPlotChEstimates(interpChannelGrid,estChannelGrid,estChannelGridNN,...
    estChannelGridPerfect)
% Plot the different channel estimates and display the measured MSE
% Copyright 2022 The MathWorks, Inc.

% Calculate the mean squared error (MSE) of each estimation method.
neural_mse = mean(abs(estChannelGridPerfect(:) - estChannelGridNN(:)).^2);
interp_mse = mean(abs(estChannelGridPerfect(:) - interpChannelGrid(:)).^2);
practical_mse = mean(abs(estChannelGridPerfect(:) - estChannelGrid(:)).^2);

figure

subplot(1,4,1)
imagesc(abs(interpChannelGrid));
xlabel('OFDM Symbol');
ylabel('Subcarrier');
title({'Linear Interpolation', ['MSE: ', num2str(interp_mse)]});

subplot(1,4,2)
imagesc(abs(estChannelGrid));
xlabel('OFDM Symbol');
ylabel('Subcarrier');
title({'Practical Estimator', ['MSE: ', num2str(practical_mse)]});

subplot(1,4,3)
imagesc(abs(estChannelGridNN));
xlabel('OFDM Symbol');
ylabel('Subcarrier');
title({'Neural Network', ['MSE: ', num2str(neural_mse)]});

subplot(1,4,4)
imagesc(abs(estChannelGridPerfect));
xlabel('OFDM Symbol');
ylabel('Subcarrier');
title({'Actual Channel'});
end