%% SimpleScreenCalibration: simple code to display different luminance values for monitor calibration.
% Written by Michael-Paul Schallmo, adapted by Alex White, March 2017
%
% This script uses Psychtoolbox to present full-screen fields of colors of increasing brightness to measure
% with a photometer. It can do grayscale only (separateColors = false) or grascale + each color gun
% separately (separateColors = true).
% It optionally records measured luminance values typed into the comamnd line (if recordLums = true).
% After a keystroke, it presents a field of purple for 1 s and then
% presents the next color.
%
% It can also fit a gama function and generate a noramlized lookup table to
% linearize the screen.
%
% Saves all results in a file called "calib"
% Finally, it can load in a normalized luminance table to check if the correction
% worked (if measure = 0).

clear; close all; clear mex;

%% Choices:

%screen name
screenName = 'ViewPixxEEG';

%name to save this as:
calDataFile = 'ViewPixxEEG';

%whether to measure each color channel separately or grayscale
separateColors = 1; % 1 for RGB+grayscale, 0 for grayscale

%number of luminance steps between 0 and 255:
nSteps = 9;

%number of cycles through all colors. Final values are then averaged:
nReps = 2;

%whether to measure uncorrected luminacne or check corrected luminance
measure = 1; % 1 for measuring, 0 for checking

%file with normalized luminance lookup table to load, if checking for
%linearity (measure  = 0)
lookupTableFile = 'ViewPixxEEG_RGBW_15-Oct-2019.mat';

%whether to collect and store measured luminance values typed in the command
%window:
recordLums = true;

%whether to fit gamma functions and generate normalized lookup table
doFitGamma = true;

%what to do with missing values at low luminance, for fitting purposes?
%if the photometer returns no value b/c too dark, enter NaN and then those
%values will be replaced by the following:
missingLumVal = 0.5;
%Leaving at NaN runs a risk of exaggerating gamma fit value.

%whether to print input luminance values to screen and require an
%additional keypress to confirm (if you don't have a secondary display to
%see the Matlab command window.
printLumsToScreen = true;
%% other parameters about this screen that you want to save
bitsPlusPlus = 0;

screenSize = [53 29.8];
resolution = [1920 1080];
refreshRate = 120;
viewingDistance = 70;


info.location = 'CERAS 126';
info.lighting = 'lights on';



%% other parameters of procedure:
stepDuration = 0; % seconds at each luminance level ... set to 0 if you're doing a manual cal and want key press to advance
blankDuration = 1; % seconds for screen between levels
blankColor = [200 0 255]; % blue, copying Huseyin

backgroundColor = 127;
fontSize = 32;
fontColor = [0 0 0];

screenLevels = round(linspace(0,255,nSteps));
if bitsPlusPlus
    nBits = 14;
else
    nBits = 8;
end

%initialize matric of measured luminance levels:
if separateColors
    nChannels = 4;
    luminance = NaN(3,nSteps,nReps);
    calDataFile = [calDataFile '_RGBW'];
else
    nChannelfs = 1;
    luminance = NaN(1,nSteps,nReps);
    calDataFile = [calDataFile '_Gray'];
end

if ~measure
    calDataFile = [calDataFile '_LinearityCheck'];
else
    lookupTableFile = '';
end

%% set where to store
codeFolder = fileparts(which('SimpleScreenCalibration'));
resFolder = fullfile(codeFolder,'results');
if ~exist(resFolder,'dir')
    mkdir(resFolder);
end
addpath(resFolder);
calDataFile = sprintf('%s_%s.mat',calDataFile,date);
figName = sprintf('%s_%s.fig',calDataFile,date);
figNameGray = sprintf('%s_%s_Gray.fig',calDataFile,date);
figNameAdd= sprintf('%s_%s_Additivity.fig',calDataFile,date);

calDataFile = fullfile(resFolder,calDataFile);
figName = fullfile(resFolder,figName);
figNameGray = fullfile(resFolder,figNameGray);
figNameAdd = fullfile(resFolder,figNameAdd);

acceptKeys = [KbName('Return') KbName('Space')];

%% Load in a normalized gamma table to check linearity
if  ~measure
    calibFile = lookupTableFile;
    load(calibFile);
    ngt = calib.normlzdGammaTable;
    
    if size(ngt,2)==1
        ngt = repmat(ngt,1,3);
    end
    clear calib;
end

%% Open screen

try %% this try/catch/end stuff is in here for OS X in case something crashes ...
    
    Screen('Preference', 'SkipSyncTests', 1);
    screenNumber = max(Screen('Screens'));
    if bitsPlusPlus
        [window,screenRect] = BitsPlusPlus('OpenWindowBits++',screenNumber);
    else
        [window,screenRect] = Screen('OpenWindow',screenNumber,backgroundColor);
    end
    
    if measure
        % make sure we're working with default linear clut
        if bitsPlusPlus
            BitsPlusPlus('LoadIdentityClut',window);
        else
            Screen ('LoadNormalizedGammaTable', window, (0:255)'*ones(1,3)./255,2);
        end
    else % we're checking to see if the measurement and gamma correction was OK
        BackupCluts;
        Screen('LoadNormalizedGammaTable',window,ngt);
    end
    
    for rep = 1:nReps
        
        HideCursor(window);
        Screen('TextFont',window, 'Arial');
        Screen('TextSize',window, fontSize);
        Screen('FillRect',window,backgroundColor,[]);
        Screen('DrawText',window,sprintf('Press any key to begin repetition %i of %i',rep,nReps), screenRect(3)/2 - 9*fontSize,screenRect(4)/2 - fontSize/2,fontColor,backgroundColor);
        Screen('Flip',window);
        
        keyIsDown = 0;
        disp('Waiting for key press ...');
        while ~keyIsDown
            keyIsDown = KbCheck;
        end
        Screen('FillRect',window,blankColor);
        Screen('Flip',window);
        WaitSecs(blankDuration);
        
        %% start measuring:
        for channelI = 1:nChannels
            for step = 1 :length(screenLevels)
                fprintf(1,'\nWorking on channel %i, step %i of %i\n',channelI,step,nSteps);
                if separateColors && channelI<4
                    color = [0 0 0]; color(channelI) = screenLevels(step);
                else
                    color = ones(1,3)*screenLevels(step);
                end
                Screen('FillRect',window,color);
                Screen('Flip',window);
                FlushEvents('KeyDown');
                
                if stepDuration>0
                    WaitSecs(stepDuration);
                else
                    if recordLums
                        
                        acceptLum = false;
                        while ~acceptLum
                            gotLum = false;
                            while ~gotLum
                                lum = input('Enter luminance:  ');
                                gotLum = isnumeric(lum) && ~isempty(lum);
                                if gotLum, gotLum = lum>=0 || isnan(lum) ; end
                            end
                            
                            if printLumsToScreen
                                Screen('DrawText',window,sprintf('%.3f. Return to accept, space to re-do.',lum), screenRect(3)/2 - 9*fontSize,screenRect(4)/2 - fontSize/2,fontColor,backgroundColor);
                                Screen('Flip',window);
                                WaitSecs(0.5); FlushEvents('KeyDown');
                                keyPressed = 0;
                                while keyPressed==0
                                    keyPressed = checkTarPress(acceptKeys);
                                end
                                acceptLum = keyPressed==1;
                                if ~acceptLum
                                    Screen('FillRect',window,color);
                                    Screen('Flip',window);
                                end
                            else
                                acceptLum = true;
                            end
                        end
                        luminance(channelI,step,rep) = lum;
                    else
                        fprintf(1,'\nPress any key to continue\n');
                        pause
                    end
                end
                Screen('FillRect',window,blankColor);
                Screen('Flip',window);
                WaitSecs(blankDuration);
            end % trial loop
        end
        
    end
    Screen('CloseAll');
catch myerror
    Screen('CloseAll');
    rethrow(myerror);
end

meanLuminance = mean(luminance,3);

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
