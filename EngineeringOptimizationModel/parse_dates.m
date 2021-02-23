function [date_array, err_ids] = parse_dates(raw_dates)
  EXCEL_EPOCH = epo = [1899,12,30,0,0,0];
  for i=1:length(raw_dates)
    [num, isnum] = str2num(raw_dates{i});
    isnum &= isempty(regexp(raw_dates{i}, '[^\d\.]','once'));
    isnum &= length(regexp(raw_dates{i}, '\.')) <= 1;
    
    % empty cell (no date)
    if isempty(raw_dates{i})
      date_array(i) = NaN;
    % kobo format
    elseif isnum
      date_array(i) = num * 24;
    % excel format
    else
      try
        fmt = '%n-%n-%nT%n:%n:%n%s';
        output = textscan(raw_dates{i},fmt);
        year = output{1};
        month = output{2};
        day = output{3};
        hour = output{4};
        minute = output{5};
        second = output{6};
        if (isnan(second))
          second = 0;
        end
        
        date_array(i)=etime([year,month,day,hour,minute,second],epo)/3600;
      catch
        data_array(i) = NaN;
        disp(printf('Invalid date at %d',i));
        err_ids(end+1) = i;
      end
    end
  end
endfunction
