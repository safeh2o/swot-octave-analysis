function [date_array] = parse_dates(raw_dates)
  for i=1:size(raw_dates,1)
    [num, isnum] = str2num(raw_dates{i});
    
    % empty cell (no date)
    if isempty(raw_dates{i})
      date_array(i) = NaN;
    % kobo format
    elseif isnum
      if i == 1 && num < 4000
        num = num + 40000;
      end
      date_array(i) = num * 24;
    % excel format
    else
      timestart=find(raw_dates{i}=='T');
      hr=str2num(raw_dates{i}(timestart+1:timestart+2));
      minute=str2num(raw_dates{i}(timestart+4:timestart+5));
      if size(raw_dates{i}) > 16
        second = str2num(raw_dates{i}(timestart+7:timestart+8));
      else
        second = 0;
      end
      date_array(i)=hr+minute/60+second/3600; 
    end
  end
endfunction
