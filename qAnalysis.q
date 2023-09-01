/ Load the table
d:("DTSFFFFF";enlist ",") 0:`$"daily.csv"
h:("DTSFFFFF";enlist ",") 0:`$"hourly.csv"
d: `sym`date xasc d
h: `sym`date`time xasc h
\c 100 1000

/Defines functions to calculate moving averages (EMA) and MACD indicators.
MA:{[x;n] n mavg x};
EMA:{[x;n] ema[2%(n+1);x]};
MACD:{[x;nFast;nSlow;nSig] diff:EMA[x;nFast]-EMA[x;nSlow]; sig:EMA[diff;nSig]; diff - sig};

cross_signal:{[m]
    m: update signalside:?[signal>0;1i;-1i], j:sums 1^i - prev i by sym from m;
    m: update signalidx:fills ?[0= deltas signalside;0N;j] by sym from m;
    update n:sums abs signalside, signaltime:first time, signalprice:first close by sym,signalidx from m
    }; 
 
cross_signal_bench:{[m]
    r: select from cross_signal[m] where n=1, 1 = abs signalside ;
    r: r upsert 0!select by sym from m; 
    r:update bps:10000*signalside*-1+pxexit%pxenter, nholds:(next j)-j by sym from update pxexit:next pxenter by sym from `sym`time xasc r;
    delete from r where null signalside
    };

/Defines functions to generate trading signals and calculate performance metrics for EMA and MACD crossover strategies on daily and hourly data.
ema_cross_over:{[data; ival; jval]
    data: update emaS:EMA[close;ival], emaL:EMA[close;jval] by sym from data;
    result: cross_signal_bench[update time:date, signal:emaS-emaL, pxenter:next open by sym from data];
    result: update ival:ival,jval:jval from result;
    res: select n:count i, avg bps, rtn_sum:sum bps%10000, rtn_prd:-1+prd 1+bps%10000, duration:avg nholds, winpct:(count i where bps>0)%count i,winmax:max bps%10000, maxloss:min bps%10000  by ival, jval, sym from result;
    res
    }

macd_cross_over:{[data; ival; jval; kval]
    data: update macd:MACD[close;ival;jval;kval] by sym from data;
    result:cross_signal_bench[update time:date, signal:macd, pxenter:next open by sym from data];
    result:update ival:ival, jval:jval, kval:kval from result;
    res: select n:count i, avg bps, rtn_sum:sum bps%10000, rtn_prd:-1+prd 1+bps%10000, duration:avg nholds, winpct:(count i where bps>0)%count i,winmax:max bps%10000, maxloss:min bps%10000  by ival,jval,kval,sym from result;
    res
    }

ema_cross_over_hourly:{[data; ival; jval]
    data: update emaS:EMA[close;ival], emaL:EMA[close;jval] by sym from data;
    result: cross_signal_bench[update signal:emaS-emaL, pxenter:next open by sym from data];
    result: update ival:ival,jval:jval from result;
    res: select n:count i, avg bps, rtn_sum:sum bps%10000, rtn_prd:-1+prd 1+bps%10000, duration:avg nholds, winpct:(count i where bps>0)%count i,winmax:max bps%10000, maxloss:min bps%10000  by ival, jval,sym from result;
    res
    }

macd_cross_over_hourly:{[data; ival; jval; kval]
    data: update macd:MACD[close;ival;jval;kval] by sym from data;
    result:cross_signal_bench[update signal:macd, pxenter:next open by sym from data];
    result:update ival:ival, jval:jval, kval:kval from result;
    res: select n:count i, avg bps, rtn_sum:sum bps%10000, rtn_prd:-1+prd 1+bps%10000, duration:avg nholds, winpct:(count i where bps>0)%count i,winmax:max bps%10000, maxloss:min bps%10000  by ival,jval,kval,sym from result;
    res
    }

/Sets up parameter ranges for EMA and MACD strategies
/Iterates over the parameter sets and applies the EMA and MACD crossover strategies to daily and hourly data, storing the results.
firstPos: 1 + 3 * til 30
secondPos: 3 + 3 * til 60

ema_params: raze {x,'/:y where x </: y}[;secondPos] each firstPos

temp: d
ema_daily_res:();
counter:0;
while[counter < count ema_params;
    cur: ema_params[counter];
    ival: cur 0;
    jval: cur 1;
    temp_res: ema_cross_over[temp;ival;jval];
    ema_daily_res:: ema_daily_res uj temp_res;
    counter+: 1;];

temp2: h
ema_hourly_res:();
counter:0;
while[counter < count ema_params;
    cur: ema_params[counter];
    ival: cur 0;
    jval: cur 1;
    temp_res: ema_cross_over_hourly[temp2;ival;jval];
    ema_hourly_res:: ema_hourly_res uj temp_res;
    counter+: 1;];

save `ema_daily_res.csv
save `ema_hourly_res.csv

firstPos: 5 + til 10;
secondPos: 20 + til 11;
thirdPos: 5 + til 7;

macd_params: firstPos cross secondPos cross thirdPos;

temp: d
macd_daily_res:();
counter:0;
while[counter < count macd_params;
    cur: macd_params[counter];
    ival: cur 0;
    jval: cur 1;
    kval: cur 2;
    temp_res: macd_cross_over[temp;ival;jval;kval];
    macd_daily_res:: macd_daily_res uj temp_res;
    counter+: 1;];

temp2: h
macd_hourly_res:();
counter:0;
while[counter < count macd_params;
    cur: macd_params[counter];
    ival: cur 0;
    jval: cur 1;
    kval: cur 2;
    temp_res: macd_cross_over_hourly[temp2;ival;jval;kval];
    macd_hourly_res:: macd_hourly_res uj temp_res;
    counter+: 1;];

save `macd_daily_res.csv
save `macd_hourly_res.csv

/ Updates the ema_daily_res and ema_hourly_res tables with the calculated high-risk (HR) and low-risk (LR) scores for EMA strategy.
ema_daily_res: update score_hr:0.3 * bps%10000 + 0.2 * rtn_sum + 0.1 * winpct + 0.3 * winmax + 0.1 * maxloss,
                        score_lr:0.1 * bps%10000 + 0.1 * rtn_sum + 0.4 * winpct + 0.1 * winmax + 0.3 * maxloss
               from ema_daily_res
ema_hourly_res: update score_hr:0.3 * bps%10000 + 0.2 * rtn_sum + 0.1 * winpct + 0.3 * winmax + 0.1 * maxloss,
                        score_lr:0.1 * bps%10000 + 0.1 * rtn_sum + 0.4 * winpct + 0.1 * winmax + 0.3 * maxloss
               from ema_hourly_res
save `ema_daily_res.csv
save `ema_hourly_res.csv

/Selects the optimal EMA parameter sets for daily and hourly data based on the maximum HR and LR scores.
hr_ema_daily: select ival, jval, sym, score_hr from ema_daily_res where score_hr=(max;score_hr) fby sym
lr_ema_daily: select ival, jval, sym, score_lr from ema_daily_res where score_lr=(max;score_lr) fby sym
hr_ema_hourly: select ival, jval, sym, score_hr from ema_hourly_res where score_hr=(max;score_hr) fby sym
lr_ema_hourly: select ival, jval, sym, score_lr from ema_hourly_res where score_lr=(max;score_lr) fby sym

hr_ema_daily
lr_ema_daily
hr_ema_hourly
lr_ema_hourly

/ Updates the macd_daily_res and macd_hourly_res tables with the calculated high-risk (HR) and low-risk (LR) scores for MACD strategy.
macd_daily_res: update score_hr:0.3 * bps%10000 + 0.2 * rtn_sum + 0.1 * winpct + 0.3 * winmax + 0.1 * maxloss,
                        score_lr:0.1 * bps%10000 + 0.1 * rtn_sum + 0.4 * winpct + 0.1 * winmax + 0.3 * maxloss
               from macd_daily_res
macd_hourly_res: update score_hr:0.3 * bps%10000 + 0.2 * rtn_sum + 0.1 * winpct + 0.3 * winmax + 0.1 * maxloss,
                        score_lr:0.1 * bps%10000 + 0.1 * rtn_sum + 0.4 * winpct + 0.1 * winmax + 0.3 * maxloss
               from macd_hourly_res
save `macd_daily_res.csv
save `macd_hourly_res.csv

/Selects the optimal MACD parameter sets for daily and hourly data based on the maximum HR and LR scores.
hr_macd_daily: select ival, jval, kval, sym, score_hr from macd_daily_res where score_hr=(max;score_hr) fby sym
lr_macd_daily: select ival, jval, kval, sym, score_lr from macd_daily_res where score_lr=(max;score_lr) fby sym
hr_macd_daily
lr_macd_daily

hr_macd_hourly: select ival, jval, kval, sym, score_hr from macd_hourly_res where score_hr=(max;score_hr) fby sym
lr_macd_hourly: select ival, jval, kval, sym, score_lr from macd_hourly_res where score_lr=(max;score_lr) fby sym
hr_macd_hourly
lr_macd_hourly


/ Subsitute EMA optimal parameter sets for daily and hourly data
data: d
ema_cross_over[data; 22; 69]
ema_cross_over[data; 88; 180]

data: h
ema_cross_over_hourly[data; 73;108]
ema_cross_over_hourly[data; 88;177]

/ Subsitute MACD optimal parameter sets for daily and hourly data
data: d
macd_cross_over[data; 11; 29; 11] /eth
macd_cross_over[data; 14; 26; 11] /btc

data: h
macd_cross_over_hourly[data; 12; 24; 9] /btc
macd_cross_over_hourly[data; 14; 29; 10] /eth

/benchmark
select -1+(last close)% first close by sym from d
select -1+(last close)% first close by sym from h

/ define a function to calculate the performance metrics of EMA strategies on a yearly basis.
ema_res_by_year:{[data; ival; jval]
    data: update emaS:EMA[close;ival], emaL:EMA[close;jval] by sym from data;
    result: cross_signal_bench[update time:date, signal:emaS-emaL, pxenter:next open by sym from data];
    res: select n:count i, avg bps, rtn_sum:sum bps%10000, rtn_prd:-1+prd 1+bps%10000, duration:avg nholds, winpct:(count i where bps>0)%count i,winmax:max bps%10000, maxloss:min bps%10000  by sym, date.year from result;
    res
    }
data: d
ema_res_by_year[data; 22; 69] /btc
ema_res_by_year[data; 88; 180] /eth
data: h
ema_res_by_year[data; 73; 108] /btc
ema_res_by_year[data; 88; 177] /eth


/ define a function to calculate the performance metrics of MACD strategies on a yearly basis.
macd_res_year:{[data; ival; jval; kval]
    data: update macd:MACD[close;ival;jval;kval] by sym from data;
    result:cross_signal_bench[update time:date, signal:macd, pxenter:next open by sym from data];
    res: select n:count i, avg bps, rtn_sum:sum bps%10000, rtn_prd:-1+prd 1+bps%10000, duration:avg nholds, winpct:(count i where bps>0)%count i,winmax:max bps%10000, maxloss:min bps%10000  by sym, date.year from result;
    res
    }
data: d
macd_res_year[data;14; 26; 11] /btc
macd_res_year[data;11; 29; 11] /eth
data:h
macd_res_year[data;12; 24; 9] /btc
macd_res_year[data;14; 29; 10] /eth


/ define a function to calculate the performance metrics of EMA strategies on a yearly basis.
ema_res_by_side:{[data; ival; jval]
    data: update emaS:EMA[close;ival], emaL:EMA[close;jval] by sym from data;
    result: cross_signal_bench[update time:date, signal:emaS-emaL, pxenter:next open by sym from data];
    res: select n:count i, avg bps, rtn_sum:sum bps%10000, rtn_prd:-1+prd 1+bps%10000, duration:avg nholds, winpct:(count i where bps>0)%count i,winmax:max bps%10000, maxloss:min bps%10000  by sym,signalside from result;
    res
    }
data: d
ema_res_by_side[data; 22; 69] /btc
ema_res_by_side[data; 88; 180] /eth
data: h
ema_res_by_side[data; 73; 108] /btc
ema_res_by_side[data; 88; 177] /eth

/ define a function to calculate the performance metrics of EMA strategies by side.
macd_res_side:{[data; ival; jval; kval]
    data: update macd:MACD[close;ival;jval;kval] by sym from data;
    result:cross_signal_bench[update time:date, signal:macd, pxenter:next open by sym from data];
    res: select n:count i, avg bps, rtn_sum:sum bps%10000, rtn_prd:-1+prd 1+bps%10000, duration:avg nholds, winpct:(count i where bps>0)%count i,winmax:max bps%10000, maxloss:min bps%10000  by sym,signalside  from result;
    res
    }
data: d
macd_res_side[data;14; 26; 11] /btc
macd_res_side[data;11; 29; 11] /eth
data:h
macd_res_side[data;12; 24; 9] /btc
macd_res_side[data;14; 29; 10] /eth


