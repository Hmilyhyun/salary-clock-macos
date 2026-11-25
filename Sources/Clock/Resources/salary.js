// SPDX-FileCopyrightText: 2026 Mr.Baoboer
// SPDX-License-Identifier: AGPL-3.0-only
//
// Additional terms: see /legal/ADDITIONAL_TERMS.md

                                                        

                          
                    
              
                 
             
                 
                 

                            
                         
                        
                      
                     
                           
                     
                    
                  
                     
                   
                            
  

                              
                      
                      
                     
                     
                     
                   
                     
                       
                      
                        
                           
                       
  

                                 
                                         
                  
  

const defaultSalaryConfig               = {
  salaryType: "monthly",
  monthlySalary: 10000,
  dailySalary: 360,
  hourlyRate: 45,
  workDaysPerMonth: 22,
  workdays: [1, 2, 3, 4, 5],
  startTime: "09:30",
  endTime: "18:30",
  lunchStart: "12:00",
  lunchEnd: "13:30",
  enableLunchBreak: false,
};

const emptySnapshot                 = {
  earnedToday: 0,
  dailySalary: 0,
  hourlyRate: 0,
  minuteRate: 0,
  secondRate: 0,
  progress: 0,
  isWorking: false,
  status: "invalid-config",
  workMsToday: 0,
  elapsedWorkMs: 0,
  nextTransitionMs: 0,
  isNightWork: false,
};

// SPDX-FileCopyrightText: 2026 Mr.Baoboer
// SPDX-License-Identifier: AGPL-3.0-only
//
// Additional terms: see /legal/ADDITIONAL_TERMS.md

const clamp = (value        , min        , max        ) =>
  Math.min(Math.max(value, min), max);

const parseTimeToMinutes = (time        ) => {
  const match = /^(\d{1,2}):(\d{2})$/.exec(time);
  if (!match) return Number.NaN;

  const hour = Number(match[1]);
  const minute = Number(match[2]);

  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return Number.NaN;
  }

  return hour * 60 + minute;
};

const normalizeWorkEnd = (start        , end        ) =>
  end < start ? end + 24 * 60 : end;

const normalizeTimeInsideWorkWindow = (value        , workStart        ) =>
  value < workStart ? value + 24 * 60 : value;

const normalizeBreakEnd = (breakStart        , breakEnd        ) => {
  let normalizedEnd = breakEnd;

  while (normalizedEnd <= breakStart) {
    normalizedEnd += 24 * 60;
  }

  return normalizedEnd;
};

const dateAtMinutes = (base      , minutes        ) => {
  const date = new Date(base);
  date.setHours(Math.floor(minutes / 60), minutes % 60, 0, 0);
  return date;
};

const previousDate = (date      ) => {
  const previous = new Date(date);
  previous.setDate(previous.getDate() - 1);
  return previous;
};

const startOfLocalDay = (date      ) => {
  const day = new Date(date);
  day.setHours(0, 0, 0, 0);
  return day;
};

// SPDX-FileCopyrightText: 2026 Mr.Baoboer
// SPDX-License-Identifier: AGPL-3.0-only
//
// Additional terms: see /legal/ADDITIONAL_TERMS.md

                                             


                                             

function isConfiguredWorkday(date      , config              ) {
  if (!Array.isArray(config.workdays) || config.workdays.length <= 0) {
    return false;
  }

  return config.workdays.includes(date.getDay());
}

function createWorkSpans(date      , config              )                      {
  if (!isConfiguredWorkday(date, config)) {
    return [];
  }

  const start = parseTimeToMinutes(config.startTime);
  const end = parseTimeToMinutes(config.endTime);

  if (![start, end].every(Number.isFinite) || start === end) {
    return [];
  }

  const workEnd = normalizeWorkEnd(start, end);

  if (!config.enableLunchBreak) {
    return [[dateAtMinutes(date, start), dateAtMinutes(date, workEnd)]]         ;
  }

  const lunchStart = parseTimeToMinutes(config.lunchStart);
  const lunchEnd = parseTimeToMinutes(config.lunchEnd);

  if (![lunchStart, lunchEnd].every(Number.isFinite)) {
    return [];
  }

  const normalizedLunchStart = normalizeTimeInsideWorkWindow(lunchStart, start);
  const normalizedLunchEnd = normalizeBreakEnd(normalizedLunchStart, lunchEnd);

  if (
    start < normalizedLunchStart &&
    normalizedLunchStart < normalizedLunchEnd &&
    normalizedLunchEnd < workEnd
  ) {
    return [
      [dateAtMinutes(date, start), dateAtMinutes(date, normalizedLunchStart)],
      [dateAtMinutes(date, normalizedLunchEnd), dateAtMinutes(date, workEnd)],
    ]         ;
  }

  return [];
}

const isWithinSpanBounds = (now      , spans                     ) => {
  if (spans.length <= 0) return false;

  const firstStart = spans[0][0].getTime();
  const lastEnd = spans[spans.length - 1][1].getTime();
  const nowMs = now.getTime();

  return nowMs >= firstStart && nowMs <= lastEnd;
};

const didSpanEndToday = (now      , spans                     ) => {
  if (spans.length <= 0) return false;

  const lastEnd = spans[spans.length - 1][1];

  return (
    now > lastEnd &&
    now.getFullYear() === lastEnd.getFullYear() &&
    now.getMonth() === lastEnd.getMonth() &&
    now.getDate() === lastEnd.getDate()
  );
};

const hasNotReachedFirstSpan = (now      , spans                     ) =>
  spans.length > 0 && now < spans[0][0];

const resolveWorkSpans = (now      , config              ) => {
  const previousSpans = createWorkSpans(previousDate(now), config);

  if (isWithinSpanBounds(now, previousSpans)) {
    return previousSpans;
  }

  const currentSpans = createWorkSpans(now, config);
  if (
    didSpanEndToday(now, previousSpans) &&
    (currentSpans.length <= 0 || hasNotReachedFirstSpan(now, currentSpans))
  ) {
    return previousSpans;
  }

  return currentSpans;
};

// SPDX-FileCopyrightText: 2026 Mr.Baoboer
// SPDX-License-Identifier: AGPL-3.0-only
//
// Additional terms: see /legal/ADDITIONAL_TERMS.md


                                             

const nightWorkStartHour = 22;
const nightWorkEndHour = 6;

const localHourDate = (date      , hour        ) => {
  const value = startOfLocalDay(date);
  value.setHours(hour, 0, 0, 0);
  return value;
};

const isWithinNightWorkWindow = (date      ) => {
  const hour = date.getHours();
  return hour >= nightWorkStartHour || hour < nightWorkEndHour;
};

const intervalsOverlap = (start      , end      , windowStart      , windowEnd      ) =>
  start < windowEnd && end > windowStart;

const spansTouchNightWorkWindow = (spans                     ) => {
  for (const [spanStart, spanEnd] of spans) {
    const firstWindowDay = startOfLocalDay(spanStart);
    firstWindowDay.setDate(firstWindowDay.getDate() - 1);

    for (let dayOffset = 0; dayOffset < 4; dayOffset += 1) {
      const windowDay = new Date(firstWindowDay);
      windowDay.setDate(firstWindowDay.getDate() + dayOffset);
      const windowStart = localHourDate(windowDay, nightWorkStartHour);
      const windowEnd = localHourDate(windowDay, nightWorkEndHour);
      windowEnd.setDate(windowEnd.getDate() + 1);

      if (intervalsOverlap(spanStart, spanEnd, windowStart, windowEnd)) {
        return true;
      }
    }
  }

  return false;
};

// SPDX-FileCopyrightText: 2026 Mr.Baoboer
// SPDX-License-Identifier: AGPL-3.0-only
//
// Additional terms: see /legal/ADDITIONAL_TERMS.md

                                                                            

                                                 

const salaryTypes               = ["monthly", "daily", "hourly"];

const maxWorkDaysPerMonth = 31;

const hasPositiveNumber = (value        ) => Number.isFinite(value) && value > 0;

const isValidWorkday = (day        ) => Number.isInteger(day) && day >= 0 && day <= 6;

function isOvernightWorkConfig(config              ) {
  const start = parseTimeToMinutes(config.startTime);
  const end = parseTimeToMinutes(config.endTime);

  return Number.isFinite(start) && Number.isFinite(end) && end < start;
}

                         
                      
                                           
            

function validateSalaryConfig(
  config              ,
  t           ,
)                      {
  const issues                      = [];
  const start = parseTimeToMinutes(config.startTime);
  const end = parseTimeToMinutes(config.endTime);
  const salaryType = config.salaryType ?? "monthly";

  if (!salaryTypes.includes(salaryType)) {
    issues.push({ field: "salaryType", message: t("validation.salaryTypeError") });
  }

  if (salaryType === "monthly" && !hasPositiveNumber(config.monthlySalary)) {
    issues.push({ field: "monthlySalary", message: t("validation.monthlyPositive") });
  }

  if (salaryType === "daily" && !hasPositiveNumber(config.dailySalary)) {
    issues.push({ field: "dailySalary", message: t("validation.dailyPositive") });
  }

  if (salaryType === "hourly" && !hasPositiveNumber(config.hourlyRate)) {
    issues.push({ field: "hourlyRate", message: t("validation.hourlyPositive") });
  }

  if (salaryType === "monthly" && !hasPositiveNumber(config.workDaysPerMonth)) {
    issues.push({
      field: "workDaysPerMonth",
      message: t("validation.workDaysPositive"),
    });
  } else if (salaryType === "monthly" && config.workDaysPerMonth > maxWorkDaysPerMonth) {
    issues.push({
      field: "workDaysPerMonth",
      message: t("validation.workDaysRange"),
    });
  }

  if (!Array.isArray(config.workdays) || config.workdays.length <= 0) {
    issues.push({ field: "workdays", message: t("validation.workdaysMinOne") });
  } else if (!config.workdays.every(isValidWorkday)) {
    issues.push({ field: "workdays", message: t("validation.workdaysError") });
  }

  if (!Number.isFinite(start)) {
    issues.push({ field: "startTime", message: t("validation.startTimeError") });
  }

  if (!Number.isFinite(end)) {
    issues.push({ field: "endTime", message: t("validation.endTimeError") });
  }

  if (Number.isFinite(start) && Number.isFinite(end) && start === end) {
    issues.push({ field: "workTime", message: t("validation.timeSameError") });
  }

  if (!config.enableLunchBreak) {
    return issues;
  }

  const lunchStart = parseTimeToMinutes(config.lunchStart);
  const lunchEnd = parseTimeToMinutes(config.lunchEnd);

  if (!Number.isFinite(lunchStart)) {
    issues.push({ field: "lunchStart", message: t("validation.lunchStartError") });
  }

  if (!Number.isFinite(lunchEnd)) {
    issues.push({ field: "lunchEnd", message: t("validation.lunchEndError") });
  }

  if (
    Number.isFinite(lunchStart) &&
    Number.isFinite(lunchEnd) &&
    lunchStart === lunchEnd
  ) {
    issues.push({ field: "workTime", message: t("validation.lunchSameError") });
    return issues;
  }

  if (
    Number.isFinite(start) &&
    Number.isFinite(end) &&
    start !== end &&
    Number.isFinite(lunchStart) &&
    Number.isFinite(lunchEnd)
  ) {
    const workEnd = normalizeWorkEnd(start, end);
    const normalizedLunchStart = normalizeTimeInsideWorkWindow(lunchStart, start);
    const normalizedLunchEnd = normalizeBreakEnd(normalizedLunchStart, lunchEnd);

    if (!(
      start < normalizedLunchStart &&
      normalizedLunchStart < normalizedLunchEnd &&
      normalizedLunchEnd < workEnd
    )) {
      issues.push({
        field: "workTime",
        message: t(
          end < start ? "validation.nightLunchOutside" : "validation.lunchOutside",
        ),
      });
    }
  }

  return issues;
}

// SPDX-FileCopyrightText: 2026 Mr.Baoboer
// SPDX-License-Identifier: AGPL-3.0-only
//
// Additional terms: see /legal/ADDITIONAL_TERMS.md






                                                 

function getDailySalary(config              , totalWorkMs        ) {
  const workHours = totalWorkMs / 3_600_000;

  if (config.salaryType === "daily") {
    return config.dailySalary;
  }

  if (config.salaryType === "hourly") {
    return config.hourlyRate * workHours;
  }

  return config.monthlySalary / config.workDaysPerMonth;
}

function getSnapshotStatus(
  now      ,
  spans                     ,
  elapsedWorkMs        ,
  totalWorkMs        ,
)               {
  if (spans.some(([start, end]) => now >= start && now < end)) {
    return "working";
  }

  if (elapsedWorkMs <= 0) {
    return "before-work";
  }

  if (elapsedWorkMs >= totalWorkMs) {
    return "after-work";
  }

  return "lunch-break";
}

function getNextTransitionMs(
  now      ,
  spans                     ,
  status              ,
) {
  const nowMs = now.getTime();

  if (status === "before-work") {
    return Math.max(0, spans[0][0].getTime() - nowMs);
  }

  if (status === "lunch-break") {
    const nextSpan = spans.find(([start]) => start.getTime() > nowMs);
    return nextSpan ? Math.max(0, nextSpan[0].getTime() - nowMs) : 0;
  }

  if (status === "working") {
    return Math.max(0, spans[spans.length - 1][1].getTime() - nowMs);
  }

  return 0;
}

const fallbackT            = (key                ) => key;

function calculateSalarySnapshot(
  now      ,
  config              ,
  t            = fallbackT,
)                 {
  const issues = validateSalaryConfig(config, t);
  if (issues.length > 0) {
    return { ...emptySnapshot, status: "invalid-config" };
  }

  const spans = resolveWorkSpans(now, config);
  if (spans.length <= 0) {
    return { ...emptySnapshot, status: "rest-day" };
  }

  const totalWorkMs = spans.reduce(
    (sum, [start, end]) => sum + Math.max(0, end.getTime() - start.getTime()),
    0,
  );

  if (totalWorkMs <= 0) {
    return { ...emptySnapshot, status: "invalid-config" };
  }

  const nowMs = now.getTime();
  const elapsedWorkMs = spans.reduce((sum, [start, end]) => {
    const spanMs = end.getTime() - start.getTime();
    return sum + clamp(nowMs - start.getTime(), 0, spanMs);
  }, 0);

  const dailySalary = getDailySalary(config, totalWorkMs);
  const workHours = totalWorkMs / 3_600_000;
  const hourlyRate = dailySalary / workHours;
  const minuteRate = hourlyRate / 60;
  const secondRate = minuteRate / 60;
  const progress = clamp(elapsedWorkMs / totalWorkMs, 0, 1);
  const status = getSnapshotStatus(now, spans, elapsedWorkMs, totalWorkMs);
  const isWorking = status === "working";
  const nextTransitionMs = getNextTransitionMs(now, spans, status);
  const isNightWork =
    (status === "working" && isWithinNightWorkWindow(now)) ||
    (status === "after-work" && spansTouchNightWorkWindow(spans));

  return {
    earnedToday: dailySalary * progress,
    dailySalary,
    hourlyRate,
    minuteRate,
    secondRate,
    progress,
    isWorking,
    status,
    workMsToday: totalWorkMs,
    elapsedWorkMs,
    nextTransitionMs,
    isNightWork,
  };
}

var Salary = {calculateSalarySnapshot};
