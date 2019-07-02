% 2019-07-01
% Loads any number of expmt structs and plots all data per your choosing
% Requires functions:
% --returnExpDate.m
% --twoChoicePrefCNE.m
% --splitROI.m
% --pickFlies.m
% --matlabColors.m
% --areaBar.m

% Clear everything but previously selected files
clear except (fileList, dirList);

% Initialize files if not already in workspace
try
    if ~strcmp(fileList,'')
        disp('The following file(s) is(are) already loaded: ');
        for n=(1:length(fileList))
            disp(fileList(n));
        end
        dispPrompt = '? Would you like to select new files? (any key or n) ';
        decision = input(dispPrompt,'s');
    end
catch
    [fileList,dirList] = deal([]);
    decision = '';
end

% Directory to look in when selecting data file
defaultDir = "D:\Harvard\Thermo\";

% If you DON'T want to keep previously-loaded files, then clear fileList
% and dirList variables
if ~strcmp(decision,'n')
    [fileList,dirList] = deal([]);
end

% Pick any number of .mat files to analyze together
while ~strcmp(decision,'n')
    [expFile,expDir] = uigetfile(strcat(defaultDir,'*.mat'),'Select a expmt .mat file containing centroid traces');
    if ~ismember(expFile,fileList)
        fileList = [fileList,string(expFile)];   
        dirList = [dirList,string(expDir)];
        disp(expFile);
    end
    dispPrompt = '? Would you like to select more files? (any key or n) ';
    decision = input(dispPrompt,'s');
end

expDir = dirList(1);

%% Initialize data struct
data = [];

% ~~ Hard-coded variables ~~
% Values expected in sexes column of survival sheet
data.sexes = {'M','F','L'};

% Values expected in treatment column of survival sheet
data.rXes = {'E','C'};

% Variables to calculate and save
data.vars = {'rawData','tempPref','runAvgPref','flyID'};

% Maximum number of frames expected for a single experiment
maxLength = 10*3600*4;

% Factor to use in downsampling if experiment was run at > 10 Hz
multiplier = 1000;

% Interval over which to measure temp preference for histogram, given in minutes
timeInt = 30;

%%
% Initialize subfields in data struct
% First level is separating data by sex
for i=(1:length(data.sexes))
   data.(data.sexes{i}) = [];

   % then by treatment
   for h=(1:length(data.rXes))
       data.(data.sexes{i}).(data.rXes{h})=[];
       
       % then by day of death (0 = didn't die)
       data.(data.sexes{i}).(data.rXes{h}).day0 = [];
       
       % the last subfield holds raw x position data and tempPrefs
       for k=(1:length(data.vars))
        data.(data.sexes{i}).(data.rXes{h}).day0.(data.vars{k}) = [];
       end

       if strcmp(data.rXes{h},'E')
            for j=(1:7)
                field = ['day',num2str(j)];
                data.(data.sexes{i}).(data.rXes{h}).(field) = [];
                
                % this is redundant, there's a more elegant way to do this that
                % eludes me currently
                for k=(1:length(data.vars))
                    data.(data.sexes{i}).(data.rXes{h}).(field).(data.vars{k}) = [];
                end
            end
       end

   end
end

% Store which files you used for analysis in data struct
data.files = fileList;

%% Load and process data 

% For every file in the list of files you just chose...
for a=(1:length(fileList))
    
    % Load the expmt stuct
    load(strcat(dirList(a),fileList(a)));
    
    % Check sampling rate and downsample to 10 Hz if CNE goofed!
    if length(expmt.Centroid.data) > maxLength
        
        % Figure out how much to resample by
        resampP = round((maxLength/length(expmt.Centroid.data)*multiplier));
        centroid = nan(ceil((resampP/multiplier)*length(expmt.Centroid.data)),expmt.nTracks);
               
        % Then resample each ROI
        for c=(1:expmt.nTracks)
            centroid(:,c) = resample(expmt.Centroid.data(:,1,c),resampP,multiplier);
        end
        
    % otherwise grab x data from expmt.Centroid.data
    else
        centroid = squeeze(expmt.Centroid.data(:,1,:));   
    end  
    
    % Correct length of experiments to all be equal
    if length(centroid) < maxLength
        missingFrames = maxLength - length(centroid);
        centroid = vertcat(centroid, nan(missingFrames,expmt.nTracks));
    elseif length(centroid) > maxLength
        centroid = centroid(1:maxLength,:);
    end
            
    % Automatically figure out name of corresponding survival sheet..
    survivalFile = strcat(dirList(a),'Meta_data_',returnExpDate(string(fileList(a))),'.xlsx');
    
    % ... and load survival sheet
    survival = readtable(survivalFile);
    
    % Pull experiment temperatures from survival data sheet (using ROI #1)
    hot = max(survival{1,'Left_temp'},survival{1,'Right_temp'});
    cold = min(survival{1,'Left_temp'},survival{1,'Right_temp'});
    
    if survival{1,'Left_temp'} == hot
        hotSide = 'L';
    else
        hotSide = 'R';
    end
    
    [tempPrefs, runAvgPref] = twoChoicePrefCNE(centroid, ...
                         expmt.ROI.centers, ...
                         expmt.ROI.bounds, ...
                         expmt.nTracks, ...
                         hotSide, hot, cold);
    
    for roi=(1:expmt.nTracks)
        currSex = survival{roi,'Sex'};
        currRx = survival{roi,'Treatment'};
        if survival{roi,'Zombie'}==1
            currDoD = survival{roi,'Day_of_death'};
        else
            currDoD = 0;
        end
        fieldDoD = strcat('day',num2str(currDoD));
        flyID = strcat('file',num2str(a),'-ROI-',num2str(roi));
        
        data.(currSex{1}).(currRx{1}).(fieldDoD).rawData = ...
            vertcat(data.(currSex{1}).(currRx{1}).(fieldDoD).rawData,centroid(roi,:));
        data.(currSex{1}).(currRx{1}).(fieldDoD).tempPref = ...
            vertcat(data.(currSex{1}).(currRx{1}).(fieldDoD).tempPref,tempPrefs(roi));
        data.(currSex{1}).(currRx{1}).(fieldDoD).runAvgPref = ...
            vertcat(data.(currSex{1}).(currRx{1}).(fieldDoD).runAvgPref,runAvgPref(roi,:));
        data.(currSex{1}).(currRx{1}).(fieldDoD).flyID = ...
            [data.(currSex{1}).(currRx{1}).(fieldDoD).flyID, {flyID}];
    end   
end

%% Pick subsets to plot
% ~~ Hard-corded options ~~
% First group for analysis
g1 = pickFlies(data,["M"],'C',0,'M-control');

% Next group for analysis (any number of groups can be analyzed as long as
% you provide enough colors in colors variable (currently set to 7)
g2 = pickFlies(data,["M"],'E',0,'M-exposed');

groups = {g1, g2};
colors = matlabColors;
% Prefix for your files
filePre = 'Exp10-11-M_only';

%% Plot temp pref histograms by time interval (histogram)

% Fractions of experiment to iterate over
timeRange = 0:1/(expmt.parameters.duration*60/timeInt):1;

% Initialize figure for all histograms
hisFig = figure();
hold on;

numCol = 3;
numRow = ceil((length(timeRange)-1)/numCol);

for i=(1:length(timeRange)-1)
    expPortion = [timeRange(i) timeRange(i+1)];
    start = floor(length(g1.runAvgPref)*expPortion(1))+1;
    stop = ceil(length(g1.runAvgPref)*expPortion(2));

    subplot(numRow,numCol,i)
    hold on;
    key = [];
    for a = 1:length(groups)
        meanTemps = mean(groups{a}.runAvgPref(:,start:stop),2);
        h = histogram(meanTemps,10,'BinLimits',[cold hot],'FaceAlpha',0.1,'FaceColor',colors{a},'Normalization','probability');
        key = [key,string(groups{a}.name)];
    end
    xlabel('Preferred temp');
    ylabel('Proportion of flies');
    title([num2str(timeInt*(i-1)),' to ',num2str(timeInt*(i)),' minutes']);
    legend(key);
end

suptitle(['Favorite temperatures over experiment',newline,data.files]);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 8 10]);
print(strcat(expDir,filePre,'-Preferred temperature histogram-',num2str(timeInt),'-min intervals'),'-dpng');  
close();

%% Plot all individual running avg preference data, colored by group (plot)
runAvg = figure();
hold on;

smoothWin = 3600*10*2;

for a = 1:length(groups)
    for b = 1:size(groups{a}.runAvgPref,1)
        plot(smoothdata(groups{a}.runAvgPref(b,:),'movmean',smoothWin),'Color',colors{a})
    end
end
ylim([cold hot]);
ylabel('Preferred temperature (degrees C)');
set(gca,'xtick',1:10*3600:length(g1.runAvgPref)+1000);
set(gca,'xticklabel',0:1:4);
xlabel('Time into experiment (hours)');
xlim([1 length(g1.runAvgPref)+1000]);
title(['Preferred temp over time',newline,data.files]);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 10 8]);
print(strcat(expDir,filePre,'-Preferred temperature over time'),'-dpng');  
close();

%% Plot mean running avg preference data for each group over time (areaBar)

% Indicate how much you'd like to downsample mean data 
% (higher number = more downsampling = faster plotting but less data per unit time)
downSamp = 1000;

meanFig = figure;
hold on;
for a = 1:length(groups)
    
    plotData = smoothdata(downsample(nanmean(groups{a}.runAvgPref),downSamp),'movmean',100);
    plotError = smoothdata(downsample(nanstd(groups{a}.runAvgPref),downSamp),'movmean',100)/sqrt(size(groups{a}.runAvgPref,1));
    
    areaBar(1:length(plotData),...
            plotData,...
            plotError,...
            colors{a},colors{a},'-',0.1);
end

xTicks = 0:round((length(plotData))/10):length(plotData);
set(gca,'xtick',xTicks,'xticklabel',0:4/length(xTicks):4);
ylim([cold hot]);
xlim([1 length(plotData)]);
title(['Mean preferred temperature',newline,expFile]);
legend(key)
ylabel('Temperature');
xlabel('Time into experiment (hours)');
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 10 8]);
print(strcat(expDir,filePre,'-Mean preferred temperature over experiment'),'-dpng');  
close();
