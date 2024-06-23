(InputDate) =>
    let
        StartDate = #date(1899, 12, 30),
        NumberOfDays = Duration.Days(Date.From(InputDate) - StartDate),
        JulianDay = NumberOfDays + 2415019 //2415018.5 
    in
        JulianDay