%show a full white screen to warm it up before calibrating 
%press return, space or escape to end

try
    Screen('Preference', 'SkipSyncTests', 1);
    screenNumber = max(Screen('Screens'));
    
    backgroundColor = [255 255 255];
    acceptKeys = [KbName('Return') KbName('Space') KbName('escape')];
    
    [window,screenRect] = Screen('OpenWindow',screenNumber,backgroundColor);
    Screen('FillRect',window,backgroundColor);
    Screen('Flip',window);
    
    keyPressed = 0;
    while keyPressed==0
        keyPressed = checkTarPress(acceptKeys);
    end 
    
    sca;
    
catch me
    sca;
end