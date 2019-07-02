function expDate = returnExpDate(fileName)
    b = strsplit(fileName,'_');
    c = strsplit(b(1),'-');
    expDate = strcat(c(1),'-',c(2),'-',c(3));
    %disp(['Experiment date: ',expDate]);
end