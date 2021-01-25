function [] = Corona_vaccination_predictions_germany()
  population = 83122889;                                                        % put in Relevant Population number here
  immunity =.75;                                                                % put in critical herd immunity assumption here, 60% is very optimistic, realistic range is 75-90%
  
  close all;                                                                    % close all open figures
  clc;                                                                          % clear command line
  
  [first_vacc_data second_vacc_data]=getRKIdata();                              % Load stored RKI vaccination data
  double_vacc_data = first_vacc_data+second_vacc_data;                          % Calculate the total number of vaccinations

  make_vacc_graph(first_vacc_data, population, 'Erstimpfung',immunity);         % Graph generation for first vaccination data
  make_vacc_graph(second_vacc_data, population, 'Zweitimpfung',immunity);       % Graph generation for second vaccination data
  make_vacc_graph(double_vacc_data, population*2, 'Doppelimpfung',immunity);    % Graph generation for double vaccination data, requires double the population number
  
endfunction

function [First Second]= getRKIdata() % Put in fresh RKI data here, use tab "Impfungen pro Tag"  https://www.rki.de/DE/Content/InfAZ/N/Neuartiges_Coronavirus/Daten/Impfquotenmonitoring.html
  First =[24258
19721
43151
57485
37922
30609
45031
24547
48675
51071
56251
57872
58111
53842
32463
65915
80214
93675
99998
90448
54429
30565
51832
56996
71446
56194
80463
46148
35023
]';
  
Second = [0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
1
11
2
55
231
467
14460
16165
27122
46735
30875
28549
38064
26025]';

endfunction


function [] = make_vacc_graph(vacc_data, population, case_string, herdimmunity) % Graph generation function: arguments: vector of vaccination data, population data, case relevant string for labels and titels, herd immunity parameter

vacc_data=remove_leading_zeros(vacc_data);                                      % Check if vacc_data is provided with leading zeros, i.e. second vaccination and remove for meaningful averaging of activities

%Basic data
pop_immunity= population*herdimmunity;                                          % Calculate population number to be immunised
n_days= numel(vacc_data);                                                       % Number of days of vaccination activity
vacc_tot= sum(vacc_data);                                                       % Total number of given vaccinations

%Simple Estimates
vacc_avg= vacc_tot/n_days;                                                      % arithmetic mean of vaccinations over all days
vacc_7d_avg= sum(vacc_data(end-7:end))/7;                                       % arithmetic mean of vaccinations of the previous 7 days

vacc_estimate_yrs_full = pop_immunity./vacc_data/365;                           % UNUSED: vector of all arithmetic mean estimates in years per day
vacc_estimate_yrs_newest= vacc_estimate_yrs_full(end);                          % UNUSED: newest arithmetic mean estimate in years per day
vacc_7d_avg_yrs= pop_immunity/vacc_7d_avg/365;                                  % Last entry of 7day averaged vector

%Linear Fitting
n_day_vector=1:n_days;                                                          % x-axis, vector of prediction_dayss from 1 to number of days, 
[data fit_data]=polyfit(n_day_vector,vacc_data,1);                              % Polynominal fitting of first degree - linear
gain_per_day=fit_data.yf(end)-fit_data.yf(end-1);                                % use a delta of 1 day of the polynominal fit to determine the slope per day


%Prediction until threshold is reached
prediction_days = 1;                                                            % Initialize the days of prediction
vacc_done =vacc_tot;                                                            % Initialize people already vaccinated

while vacc_done< pop_immunity                                                   % Loop until threshold is reached, can be optimized in case of linear fit with simple arithmetic
  vacc_done = vacc_done+vacc_data(end)+gain_per_day*prediction_days;            % y = y_0+ b*x , already done, + latest daily max vaccinations+ gain per day*days
  prediction_days = prediction_days +1;                                         % add another day
endwhile

%Results                                                                        
days_from_now= prediction_days;                                                 % number of days to reach threshold from most recent data point
duration_total=prediction_days+numel(vacc_data);                                % number of days to reach theshhold from starting of vaccination campaign

%7 day moving average vector  
mov_avg=[];                                                                     % initalize vector
for i=1:numel(vacc_data)-7                                                      % loop through vaccinatin data
  mov_avg= [mov_avg sum(vacc_data(i:i+7))/7];                                   % fill moving average vector of 7 day average data
endfor

%Plot Generation
gcf=figure;                                                                     % New figure
hold on;                                                                        % Allow multiple lines in plot
grid on;                                                                        % Activate grid lines
ylim([0 max(vacc_data)+10000]);                                                 % Set y-axis limits, 10k above maximum
xlabel('Tag seit Impfstart / d');                                               % x-axis label
ylabel(strcat(case_string,'en'));                                               % y-axis label
title({strcat('Auswertung ',{' '},case_string,{' '},date){1};strcat('Gesamt:',{' '},num2str(vacc_tot)){1}});   % Figure title

%Plot: Raw data
plot(n_day_vector,vacc_data,'k*','Markersize',5);                               % Plot points for raw RKI data

%Plot: Linear Fit
plot(n_day_vector,fit_data.yf,'r-','Linewidth',2);                              % Plot line for linear fit data

%Plot: Moving average
plot(n_day_vector(8:end),mov_avg,'b-.','Linewidth',2);                          % Plot line for 7 day average

%Annotation: Text arrow
mid_element=ceil(numel(fit_data.yf)/2);                                         % Point arrow to middle element in x-direction
mid_element_y= fit_data.yf(mid_element);                                        % Find y-value of middle element
rel_pos_y = mid_element_y/max(vacc_data);                                       % Calculate arrow target relative y-position in graph  
rel_pos_x = ceil(numel(n_days)/2);                                              % UNUSED: Calculate arrow target relative x-position in graph  
x_annot = [.4 .5];                                                              % Arrow Starting point
y_annot = [.75 rel_pos_y];                                                      % Arrow target point
annotation_text=strcat(num2str(gain_per_day,4),' zusätzliche Impfungen je Tag ');  % Annotation arrow data
annotation('textarrow',x_annot,y_annot,'String',annotation_text);               % Place annotation arrow

%Annotation: Text box
annotation('textbox',[.4 .145 .45 .1],'String',{strcat({'  '},num2str(days_from_now,3),' Tage bis', {' '},num2str(round(herdimmunity*100)),'%',{' '},case_string,' bei linearer Steigung'){1};
strcat({'  '},num2str(round(vacc_7d_avg_yrs*10)/10,3),' Jahre bis', {' '},num2str(round(herdimmunity*100)),'%',{' '},case_string,' bei konstanter Rate '){1}},"backgroundcolor", [.95 .95 .85] ,"fitboxtotext", "off"); % Line 1 and 2 of the textbox annotation

% Add legend
legend('Impfungen ','Linearer Fit','7 Tage Durchschnitt','Location','southwest');

%Save Figure as .png
saveas(gcf,strcat('VaccinationPredictionGermany_',case_string,'_',date,'.png'))


%Tweet Output
data_string =strcat('Service tweet #Corona: Bei aktueller ',{' '},case_string,'szahl von',{' '},num2str(ceil(vacc_7d_avg)), ' Personen pro Tag benötigen wir noch',{' '},num2str(round(vacc_7d_avg_yrs*10)/10),' Jahre bis ',{' '},num2str(round(herdimmunity*100)),'% ',{' '},case_string,' erreicht ist.*');
disp(data_string{1});
disp('*7 Tage Durchschnitt angesetzt.');
disp('Quelle: https://www.rki.de/DE/Content/InfAZ/N/Neuartiges_Coronavirus/Daten/Impfquotenmonitoring.html');
disp('')
endfunction


function [vacc_data]=remove_leading_zeros(vacc_data)                            % remove leading zeros of a data set, especially for 2nd vacc data´
 for i=1:numel(vacc_data)
   if vacc_data(i)!=0                                                           % if some data is unequal to zero, start the vector from there
     vacc_data=vacc_data(i:end);
     break
   end
 end
endfunction
