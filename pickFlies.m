function group = pickFlies(data, sex,treatment,day,name)
    group = [];
    
    for a=1:length(data.vars)
        group.(data.vars{a}) = [];
    end
    
    group.name = name;
    
    for i=1:length(sex)
        for j=1:length(treatment)
            for k=1:length(day)
                doD = strcat('day',num2str(day(k)));
                for a=1:length(data.vars)
                    if ~strcmp(data.vars{a},"flyID")
                        group.(data.vars{a}) = vertcat(group.(data.vars{a}), data.(sex(i)).(treatment(j)).(doD).(data.vars{a}));
                    else
                        group.(data.vars{a}) = horzcat(group.(data.vars{a}), data.(sex(i)).(treatment(j)).(doD).(data.vars{a}));
                    end
                end
            end
        end
    end
end