%% ViewPixxScreenCalibration
% This script uses a x-rite i1 Display colorimeter and VPixx's function to
% communicate with that device to measure luminance (and x-y color values)
% on a ViewPixx screen. %
% This script use s Psychtoolbox to present full-screen fields of colors of increasing brightness to measure
% with the colorimeter. It can do grayscale only (separateColors = false) or grascale + each color gun
% separately (separateColors = true).
% For each color, it calls VPixx's I1 function to get the CIE Lxy
% measurement from the device. This function is installed as part of
% VPixx's software tools. 
%
% It can also fit a gama function and generate a noramlized lookup table to
% linearize the screen.
%
% Saves all results in a file called "calib"
% Finally, it can load in a normalized luminance table to check if the correction
% worked (if measure = 0).
% 
% By Alex White, based on code by Michael-Paul Schallmo

clear all; close all;


%% Choices:

%screen name
screenName = 'ViewPixx3D';
 
%name to save this as:
calName = 'ViewPixx3D_1025';

%whether to measure each color channel separately or grayscale
separateColors = 1; % 1 for RGB+grayscale, 0 for grayscale

%number of luminance steps between 0 and 255:
nSteps = 11;

%number of cycles through all colors. Final values are then averaged:
nReps = 2; 

%whether to measure uncorrected luminance or check corrected luminance
measure = 1; % 1 for measuring, 0 for checking

%whether to fit gamma functions and generate normalized lookup table
doFitGamma = true;

%what to do with missing values at low luminance, for fitting purposes?
%if the photometer returns no value b/c too dark, enter NaN and then those
%values will be replaced by the following:
missingLumVal = 0.5;
%Leaving at NaN runs a risk of exaggerating gamma fit value.



%% other parameters of procedure:
stepDuration = 5; % seconds at each luminance level  

backgroundColor = 127;
fontSize = 32;
fontColor = [0 0 0];

screenLevels = round(linspace(0,255,nSteps));

nBits = 8;
    
%% other parameters about this screen that you want to save

screenSize = [53 30];
resolution = [1920 1080];
refreshRate = 120;
viewingDistance = 60;


info.location = 'RDSC 1025';
info.lighting = 'lights on';

%% set where to store data
codeFolder = fileparts(which(mfilename));
resFolder = fullfile(codeFolder,'results');
if ~exist(resFolder,'dir')
    mkdir(resFolder);
end
addpath(resFolder);


%initialize matrix of measured luminance levels:
if separateColors
    nChannels = 4; %R,G,B,and gray
    calName = [calName '_RGBW'];
else
    nChannels = 1;
    calName = [calName '_Gray'];
end
calName = [calName '_' date];

luminance = NaN(nChannels,nSteps,nReps);
xyColors = NaN(2,nChannels,nSteps,nReps);

if ~measure
    %file with normalized luminance lookup table to load, if checking for
    %linearity (measure  = 0)
    lookupTableFile = calName;
    calName = [calName '_LinearityCheck'];
else
    lookupTableFile = '';
end
lookupTableFile = fullfile(resFolder,lookupTableFile);

calDataFile = fullfile(resFolder, sprintf('%s.mat',calName));
figName = fullfile(resFolder,sprintf('%s.fig',calName));
figNameGray = fullfile(resFolder,sprintf('%s_Gray.fig',calName));
figNameAdd= fullfile(resFolder,sprintf('%s_Additivity.fig',calName));


%% Load in a normalized gamma table to check linearity
if ~measure
    calibFile = lookupTableFile;
    load(calibFile);
    ngt = calib.normlzdGammaTable;
    
    if size(ngt,2)==1
        ngt = repmat(ngt,1,3);
    end
    clear calib;
else
    % make sure we're working with default linear clut
    ngt = repmat((0:255)'/255, 1, 3);
end

%% Open screen

try %% this try/catch/end stuff is in here for OS X in case something crashes ...
    if I1('IsConnected')
        
        Screen('Preference', 'SkipSyncTests', 1);
        screenNumber = max(Screen('Screens'));
        
        [window,screenRect] = Screen('OpenWindow',screenNumber,backgroundColor);
        
         %Load normalized gamma table (which is simple linear ramp from 0 to
        %1 if measure==1
        BackupCluts;
        Screen('LoadNormalizedGammaTable',window,ngt);
        
        
        for rep = 1:nReps
            
            HideCursor(window);
            Screen('TextFont',window, 'Arial');
            Screen('TextSize',window, fontSize);
            Screen('FillRect',window,backgroundColor,[]);
            
            if rep==1
                Screen('DrawText',window,sprintf('Press any key to begin repetition %i of %i',rep,nReps), screenRect(3)/2 - 9*fontSize,screenRect(4)/2 - fontSize/2,fontColor,backgroundColor);
                Screen('Flip',window);
                
                keyIsDown = 0;
                disp('Waiting for key press ...');
                while ~keyIsDown
                    keyIsDown = KbCheck;
                end
                               
            else
                Screen('DrawText',window,sprintf('Beginning repetition %i of %i',rep,nReps), screenRect(3)/2 - 9*fontSize,screenRect(4)/2 - fontSize/2,fontColor,backgroundColor);
                Screen('Flip',window);
                
                WaitSecs(2);
            end
            
            
            %% start measuring:
            for channelI = 1:nChannels
                for step = 1 :length(screenLevels)
                    fprintf(1,'\nWorking on channel %i, step %i of %i\n',channelI,step,nSteps);
                    if separateColors && channelI<4
                        color = [0 0 0];
                        color(channelI) = screenLevels(step);
                    else
                        color = ones(1,3)*screenLevels(step);
                    end
                    Screen('FillRect',window,color);
                    Screen('Flip',window);
                    FlushEvents('KeyDown');
                    
                    WaitSecs(stepDuration/2);
                    %% Now we can take a new CIE Lxy measurement with VPixx's I1 function:
                    Lxy = I1('GetTriStimulus'); % Save luminance and xy colour coordinates.
                    WaitSecs(0.25);
                    
                    luminance(channelI,step,rep) = Lxy(1);
                    xyColors(:, channelI, step, rep) = Lxy(2:3);
                    WaitSecs(stepDuration/2);
                    
                end

            end % trial loop
        end
        
        Screen('CloseAll');
    else
        fprintf('No I1 detected: Connect an X-Rite device purchased from VPixx Technologies by USB, and remove the cover before measuring.');
    end
catch myerror
    Screen('CloseAll');
    rethrow(myerror);
end

%average over repetitions
if nReps>1
    meanLuminance = mean(luminance,ndims(luminance));
else
    meanLuminance = luminance;
end

%% check for additivity
if separateColors
    sum_lum = sum(meanLuminance(1:3,:),1);
    figure;
    hold on
    plot(screenLevels,sum_lum,'.-','Color',[0.8 0 1])
    plot(screenLevels,meanLuminance(4,:),'k.-')
    xlabel('output value');
    ylabel('luminance measured');
    legend({'R+G+B','Gray'},'location','NorthWest');
    title('check for additivity of color channels');
    savefig(figNameAdd);
end

%% save raw data

calib.screenName = screenName;
calib.date = date;
calib.nSteps = nSteps;
calib.nReps = nReps;
cabib.nBits = nBits;
calib.screenLevels = screenLevels;
calib.luminance = luminance;
calib.meanLuminance = meanLuminance;
calib.xyColors = xyColors;
calib.nReps = nReps;
calib.lookupTableFile = lookupTableFile;
calib.measureOrCheck = measure;
calib.screenSize = screenSize;
calib.resolution = resolution;
calib.refreshRate = refreshRate;
calib.viewingDistance = viewingDistance;
calib.info = info;

save(calDataFile,'calib')

%% Fit a gamma table!

if doFitGamma
    showFig = 1;
    
    method = 1; %subtract minimum (ingoring NaNs), and then divide by max
    
    if separateColors
        lums = meanLuminance(1:3,:)';
    else
        lums = squeeze(meanLuminance)';
    end
    
    lums(isnan(lums)) = missingLumVal;
    
    [calib.normlzdGammaTable, calib.fitGamma] = alwMakeNormGammaTable(screenLevels, lums, method, showFig);
    if showFig
        subplot(1,3,1); title(['Raw data, ' date]);
        savefig(figName);
    end
    
    %do that again for white if also done for separate colors
    if separateColors
        lums = meanLuminance(4,:)';
        [calib.normlzdGammaTable_Gray, calib.fitGamma_Gray] = alwMakeNormGammaTable(screenLevels, lums, method, showFig);
        if showFig
            subplot(1,3,1); title(['Raw data, ' date]);
            savefig(figNameGray);
        end
    end
    calib.fitMethod = method;
    
    save(calDataFile,'calib')
end
