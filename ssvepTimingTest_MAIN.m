% ssvepTimingTest_MAIN.m
% ---------------------
% Creator: Blair Kaneshiro (October 2022)
% Maintainer: Blair Kaneshiro
%
% This script loads a timing test .mat file exported from Net Station and
% assesses the timing between photodiode events.

%%
clear all; close all; clc

%%%%%%%%%%%%%%%%%%%%%%% Edit things here %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Some .mat file in path
% fnIn = 'MatlabtestNopreload1_20221010_113412.mat';
fnIn = 'MatlabtestPreload1_20221010_114133.mat';

% Trial length in seconds (determines number of expected events)
trialSec = 12;

% Whether to save figures
saveFig = 1;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

IN = load(fnIn)
%   struct with fields:
%
%     MatlabTest1_20221003_123355mff: [129×305352 single]
%                    EEGSamplingRate: 1000
%                           evt_DIN2: {4×1837 cell}
%                evt_ECI_TCPIP_55513: {4×30 cell}

% Extract photodiode events from DIN channel
try
    [dinTriggers, dinOnsets] = parseDIN_col(IN.evt_DIN1);
    assert(isequal(unique(dinTriggers), 1));
    disp('Parsed DIN1 triggers.')
catch
    [dinTriggers, dinOnsets] = parseDIN_col(IN.evt_DIN2);
    assert(isequal(unique(dinTriggers), 2));
    disp('Parsed DIN2 triggers.')
end
dinTriggers = 99 * ones(size(dinTriggers)); % Make a non-Hz value
dinCombined = [dinTriggers dinOnsets];

% Extract labeled stimulus triggers from TCP channel
[tcpTriggers, tcpOnsets] = parseTCP_xHz(IN.evt_ECI_TCPIP_55513);
tcpCombined = [tcpTriggers tcpOnsets];

%% Aggregate DIN and TCP triggers

% Iterate backward through the labelled triggers and combine each trigger
% with corresponding subsequent photodiode events.

% Data will be aggregated in a cell array called TIMESTAMPS. Each element
% of TIMESTAMPS will be an nEvent x 2 matrix.
%   - The first row will contain the trigger and onset time of the
%   labelled stimulus trigger.
%   - Subsequent rows will contain dummy trigger 99 plus corresponding
%   timestamps of the DIN (photodiode) events.

while true
    
    i = size(tcpCombined, 1);
    
    % If there are no labelled triggers remaining, break.
    if isempty(tcpCombined), break; end
    
    % Otherwise process the current labelled events
    disp(['Processing stimulus block ' num2str(i)])
    
    thisTcp = tcpCombined(end, :);
    
    thisDinIdx = find(dinCombined(:, 2) >= thisTcp(2));
    thisDin = dinCombined(thisDinIdx, :);
    
    thisAll = [thisTcp; thisDin];
    
    TIMESTAMPS{i} = thisAll;
    
    % Erase things used in this block
    tcpCombined(end,:) = [];
    dinCombined(thisDinIdx, :) = [];
    
    clear this*
    
end

%% Assess timing in each block

disp(' ')
nBlocks = length(TIMESTAMPS);
close all

for i = 1:nBlocks
    
    disp([newline 'Assessing timing in block ' num2str(i)])
    currData = TIMESTAMPS{i};
    
    currBlockHz = currData(1, 1);
    currTimestamps = currData(2:end, 2);
    currDinTriggers = currData(2:end, 1);
    assert(isequal(unique(currDinTriggers), 99))
    currNExpected = currBlockHz * trialSec;
    currNActual = length(currTimestamps);
    
    disp(['Block condition: ' num2str(currBlockHz) 'Hz'])
    disp(['Expected number of events (' num2str(trialSec) ...
        '-second trial): ' num2str(currNExpected)])
    disp(['Actual number of events registered: ' num2str(currNActual)])
    
    currDiff = diff(currTimestamps);
    currMeanDiff = mean(currDiff);
    currMinDiff = min(currDiff); currMaxDiff = max(currDiff);
    
    figure()
    plot(currDiff, '-*', 'linewidth', 2)
    hold on
    grid on; box off
    xlabel('Trial number')
    ylabel('Msec since previous timestamp')
    title(['Photodiode timestamp diff, block ' num2str(i) ...
        ' (' num2str(currBlockHz) ' Hz)'])
    ylim([currMinDiff - 1, currMaxDiff + 1])
    set(gca, 'fontsize', 16)
    plot(xlim, 1000 * 1/currBlockHz * [1 1], 'r', 'linewidth', 2)
    legend('observed', 'expected', 'location', 'best')
    
    currFnOut = ['PNG' filesep fnIn(1:(end-4)) '_block' sprintf('%02d', i) '.png'];
    if saveFig, saveas(gcf, currFnOut); else, pause(); end
    
    clear curr*
end