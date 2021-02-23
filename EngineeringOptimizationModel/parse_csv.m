function [data] = parse_csv(filepath, hasheaders=true)
  data = {};
  fid = fopen(filepath, 'rt');
  line = fgetl(fid);
  
  % skip headers
  if (hasheaders && !isnumeric(line))
    line = fgetl(fid);
  end
  while (!isnumeric(line))
    filledblanks = regexprep(line,',,',',null,');
    splitline = strsplit(filledblanks,',');
    for i=1:length(splitline)  
      data{i}{end+1} = splitline{i};
    end
    line = fgetl(fid);
  end
  
  fclose(fid);
endfunction
