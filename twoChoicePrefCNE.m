function [out, runAvgPref] = twoChoicePrefCNE(centroid, centers, bounds, nTracks, hotSide, hot, cold)

%create preference score based on occupancy of the two sides, discounting
%all centroid positions that fall in the middle (the choice point) > 2% of
%total ROI width
ROIsplit = splitROI(bounds, centers);

pref = NaN(nTracks,1);
distance = NaN(nTracks,1);
runAvgPref = NaN(nTracks,length(centroid));

for i = 1:nTracks
    idxL = centroid(:,i) > ROIsplit(i,1) & centroid(:,i) < ROIsplit(i,3);
    idxR = centroid(:,i) < ROIsplit(i,2) & centroid(:,i) > ROIsplit(i,4);
   
   if strcmp(hotSide, 'L') == 1
        pref(i) = sum(idxL)/(sum(idxR)+sum(idxL));
        idxLTemp = idxL * hot;
        idxRTemp = idxR * cold;
   end
   if strcmp(hotSide, 'R') == 1
        pref(i) = sum(idxR)/(sum(idxR)+sum(idxL));
        idxLTemp = idxL * cold;
        idxRTemp = idxR * hot;
   end
   
   runAvgTemp = idxLTemp + idxRTemp;
   runAvgTemp(runAvgTemp == 0) = mean([hot, cold]);
   runAvgPref(i,:) = runAvgTemp;
   
   d = NaN(size(centroid,1)-1,1);
   for n = 1:length(centroid)-1
        d(n) = abs(centroid(n+1,i) - centroid(n,i));
   end
   distance(i) = nansum(d);
end

out = pref;

% establish threshold to ignore flies that didn't move!
distThresh = mean(distance) - 2*(std(distance));

% remove flies that moved less that 2 std dev from average fly from set
out(distance < distThresh) = nan;
runAvgPref(distance < distThresh,:) = nan;
