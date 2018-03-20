function [normTable, fitGamma, fitLowAs] = alwMakeNormGammaTable(gunVals,luminance,method,doPlot)
% Function to generate an inverse normalized lookup table to linearize a
% display, given measured luminance levels. 
% 
% Inputs: 
% - gunVals: 1xS vector, containing the RGB gun values sent to the video card, range [0 255]. Best
% if first is 0 and last is 255. Assume they were all the same for all guns
% (red, green, blue, or gray used). S is the number of steps. 
% - luminance: a SxC matrix, containing luminance measures at S intensity
% levels, for C "channels" or guns. Could be 3 channels: red green and
% blue, or just 1 grayscale channel. 
% - method:  There are three fitting "methods" available:
%    1. Fit a exponent (gamma value) to luminance measurements normalized to 
%       the total RANGE. So to normalize luminance values (and the RGB
%       values), subtract the minimum, then divide by the total range. 
%    2. Fit a exponent (gamma value) to luminance measurements epressed as a proportion 
%       of the MAX value measured. So to normalize luminance values (and the RGB
%       values), simply divide by the max. Recommended first by J. Palmer, but
%       ALW now doesn't think it works for this purpose, because fits are bad,
%       and our goals is just to *linearize* the output luminance values, so
%       all that really matters is variation within the whole range (absolute
%       value of lowest level doesn't matter). 
%    3. Fit both an exponent and a lower asymptoite to luminance measurements expressed as a proportion 
%       of the MAX value measured. This is an attempt to improve the fits of
%       method 2. The lower asymptote tries to improve estimate of the
%       exponent (gamma), and then the inverse normalized table is generated
%       by giving output values from 0 to 1 (proportion of full range),
%       putting them to power (1/gamma), and ignoring the lower asymptote.
%
%   *Recommendation*: method 1. It's the simplest, does the job of making an inverse
%   table to linearize the output. 
%
% - doPlot: boolean, whether to make a plot. 
% 
% Outputs: 
% - normTable: 256xC matrix that is the inverse normalized gamma table,
% with one column for each "channel" or gun (red, green, blue or
% grayscale). Rows correspond to desired output, from 0 to 1 (in 256
% steps), in terms of proportion of max luminance. Values in the matrix
% tell you what gun intensity to send to the video card in order to
% linearize the output luminance. 
% - fitGamma: a 1xC vector of best-fitting exponent parameters. 
% - fitLowAs: a 1xC vector of best-fitting lower asympototes, if method=3.
% Otherwise it's empty. 
 
  

if ~exist('doPlot','var')
    doPlot = 0;
end

if ~exist('method','var')
    method = 1;
end

data_size = size(luminance);
if data_size(2) ~= 3 && data_size(2) ~= 1
    error('Data should be in a matrix of #_steps x #_color channels (RGB = 3, or grayscale = 1)')
end
nChans = size(luminance,2);

if doPlot
    figure
    set(gcf,'pos',[100 100 800 400],'color','w')
end

if nChans==1
    colors = {'k'};
else
    colors = {'r','g','b'};
end

xSteps = 0:1/255:1;
normTable = zeros(length(xSteps),nChans);

fitGamma = zeros(1,nChans);
if method==3
    fitLowAs = zeros(1,nChans);
end

for iC = 1:nChans
    %extract luminance measurements
    L = luminance(:,iC);
   
    
    % Normalize luminance (L) and the output gun values (I): 
    %
    % method 1: subtract minimum and divide by range, so we're fitting to
    % values from 0 to 1, as proportions of the total RANGE
    if method == 1 
        %strategy used in CalibrateMonitorPhotometer, a PTB function:: 
        normL  = (L - min(L))/range(L);
        %normalize gun values the same way:
        normI = (gunVals-min(gunVals))/range(gunVals);
        %        normI = gunVals/255;

    % method 2 (and 3): normalize simply by dividing by the max, so we're fitting to 
    % values from 0 to 1, as proportions of MAX luminance     
    elseif method == 2 || method == 3
        %normalize simply by dividing by the max
        normL = L/max(L);
        normI = gunVals/max(gunVals);
    end
    
        
    %exclude missing data points
    goodIs = ~isnan(L); 
    normL = normL(goodIs); 
    normI = normI(goodIs);
    
    switch method
        case {1,2}
            %fit gamma value: 
            fitGamma(iC) = alwFitGamma(normI,normL);
            %predicted luminance proportions given fit gamma
            predLs = xSteps.^fitGamma(iC);
            %inverse normalized lookup table: 
            normTable(:,iC) = xSteps.^(1/fitGamma(iC));
            
            fitLowAs = []; %not used here
        case 3
            %fit gamma value and lower asymptote
            fitParams = alwFitGammaAndLowA(normI,normL);
            fitLowAs(iC) = fitParams(1);
            fitGamma(iC) = fitParams(2);
            %predicted luminance proportions given fit parameters
            predLs = fitLowAs(iC)+xSteps.^fitGamma(iC);
            %make inverse normalized look up table. 
            %to do that, need to give as "input" only the allowable range
            %of luminance fractions, given lower asymptote. 
            %xStepsCorrectedForLowA = linspace(fitLowAs(iC),1,256);
            %normTable(:,iC) = (xStepsCorrectedForLowA-fitLowAs(iC)).^(1/fitGamma(iC));
            
            %Actually, no. Ignore the lower asymptote in generating the
            %inverse table. Just use the gamma paramter, treating input
            %values as the whole range. So, lower asymptote is fit just to
            %get a better estimate of the exponent. 
            normTable(:,iC) = xSteps.^(1/fitGamma(iC));

            %but then treat these as going from 0 to 1, in terms of output
            %range (as in methods 1 and 2)
    end

    
    if doPlot
        subplot(1,3,1)
        hold on
        plot(gunVals(goodIs),L(goodIs),[colors{iC} 'o'])
        axis([0 255 0 max(luminance(:))*1.1])
        axis square;
        xlabel('Gun intensity value');
        ylabel('cd / m^2');
        title('Raw data');
        
        subplot(1,3,2)
        hold on
        plot(normI,normL,[colors{iC} 'o'])
        plot(xSteps,predLs,[colors{iC} '-'])
        if method==3
            text(.10,.98-.06*iC,sprintf('%.3f, %.3f',fitGamma(iC),fitLowAs(iC)),'color',colors{iC});
        else
            text(.10,.98-.06*iC,sprintf('%.3f',fitGamma(iC)),'color',colors{iC});
        end
                
        axis([0 1 0 1])
        axis square;
        xlabel('Gun output (proportion)');
        ylabel('Luminance output (proportion)');
        title(sprintf('Function fits, method %i', method));
        
        subplot(1,3,3)
        hold on
        plot(xSteps,normTable(:,iC),[colors{iC} '-'])
        axis([0 1 0 1])
        axis square;
        xlabel('Desired luminance proportion'); 
        ylabel('Gun output value (proportion)');
        title('Normalized Lookup Table');
    end
end



end

function fitGamma = alwFitGamma(I,L)
    initParam = 2;
    fitGamma = lsqcurvefit(@(gamma,I) I.^(gamma),initParam,I',L);
end

function fitParams = alwFitGammaAndLowA(I,L)
    initParam = [1 0.01];
    fitParams = lsqcurvefit(@(params,I) params(1)+I.^(params(2)),initParam,I',L);
end