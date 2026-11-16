//! Command-line client for Google Calendar.
//!
//! It holds no credentials. Each call asks a token broker for an access
//! token of the account, and talks to the Calendar API directly.

use chrono::{DateTime, Days, Duration, Local, NaiveDate, NaiveDateTime, NaiveTime, TimeZone, Utc};
use clap::{Args, Parser, Subcommand};
use serde_json::{json, Map, Value};
use std::process::{Command, ExitCode};

const API: &str = "https://www.googleapis.com/calendar/v3";

const AFTER_HELP: &str = "\
Dates and times:
  today, tomorrow, or 2026-11-20, alone for an all-day event or followed by 14:00.
  A time alone means today, or the day of --start when given to --end.
  Durations are minutes, or 45m, 2h, 1h30m.

Environment:
  GCAL_ACCOUNTS   Comma-separated accounts the views read, the first one receiving new events
  GCAL_ORTIE      The ortie program that prints an access token, ortie by default
  GCAL_TIME_ZONE The zone typed times are in, such as Europe/Paris, the calendar's own by default

Exit status:
  0  Success
  1  The command failed
  2  The command line did not parse";

#[derive(Parser)]
#[command(name = "gcal", version, about = "Command-line client for Google Calendar", after_help = AFTER_HELP)]
struct Cli {
    /// Account to use, instead of every account for views and the first one for new events
    #[arg(short, long, global = true)]
    account: Option<String>,
    /// Calendar id, as printed by the calendars command
    #[arg(short, long, global = true, default_value = "primary")]
    calendar: String,
    /// Output JSON
    #[arg(long, global = true)]
    json: bool,
    #[command(subcommand)]
    command: Option<Cmd>,
}

#[derive(Subcommand)]
enum Cmd {
    /// Show today's events (default)
    Today,
    /// Show the events of the coming days
    Upcoming {
        /// Number of days, today included
        #[arg(long, default_value_t = 7)]
        days: u64,
    },
    /// Show the events between two dates
    Agenda {
        /// First day
        from: String,
        /// Last day, included
        to: String,
    },
    /// Search events by text
    Find {
        text: String,
        /// First day, today by default
        #[arg(long)]
        from: Option<String>,
        /// Last day, a year after the first by default
        #[arg(long)]
        to: Option<String>,
    },
    /// Show one event in full
    Show { id: String },
    /// Show the calendars of the accounts
    Calendars,
    /// Create an event
    New(NewArgs),
    /// Edit the title, time, location, notes, guests, or meeting link of an event
    Edit(EditArgs),
    /// Delete an event, or one occurrence when given the id of an occurrence
    Delete {
        id: String,
        /// Do not email the guests
        #[arg(long)]
        silent: bool,
    },
}

#[derive(Args)]
struct NewArgs {
    title: String,
    /// When it starts
    #[arg(short, long)]
    start: String,
    /// When it ends
    #[arg(short, long, conflicts_with = "duration")]
    end: Option<String>,
    /// How long it lasts, one hour by default
    #[arg(short, long)]
    duration: Option<String>,
    #[arg(short, long)]
    location: Option<String>,
    #[arg(short, long)]
    notes: Option<String>,
    /// daily, weekly, monthly, yearly, or a raw RRULE
    #[arg(short, long)]
    repeat: Option<String>,
    /// Repeat every this many days, weeks, months, or years
    #[arg(long, requires = "repeat")]
    every: Option<u32>,
    /// Last day it repeats on
    #[arg(long, requires = "repeat", conflicts_with = "count")]
    until: Option<String>,
    /// Number of occurrences
    #[arg(long, requires = "repeat")]
    count: Option<u32>,
    /// Guest email address, repeatable. Guests are emailed an invitation
    #[arg(short, long)]
    invite: Vec<String>,
    /// Add a Google Meet link
    #[arg(short, long)]
    meet: bool,
}

#[derive(Args)]
struct EditArgs {
    id: String,
    #[arg(short, long)]
    title: Option<String>,
    /// New start. The length is kept unless --end or --duration is given
    #[arg(short, long)]
    start: Option<String>,
    #[arg(short, long, conflicts_with = "duration")]
    end: Option<String>,
    #[arg(short, long)]
    duration: Option<String>,
    #[arg(short, long)]
    location: Option<String>,
    #[arg(short, long)]
    notes: Option<String>,
    /// Guest email address to add, repeatable
    #[arg(short, long)]
    invite: Vec<String>,
    /// Add a Google Meet link
    #[arg(short, long)]
    meet: bool,
    /// Do not email the guests
    #[arg(long)]
    silent: bool,
}

type Res<T> = Result<T, String>;

enum When {
    Day(NaiveDate),
    Time(NaiveDateTime),
}

fn parse_day(text: &str) -> Res<NaiveDate> {
    let today = Local::now().date_naive();
    match text.to_ascii_lowercase().as_str() {
        "today" => Ok(today),
        "tomorrow" => today
            .succ_opt()
            .ok_or_else(|| "date out of range".to_string()),
        other => NaiveDate::parse_from_str(other, "%Y-%m-%d").map_err(|_| {
            format!("`{text}` is not a date, expected today, tomorrow, or 2026-11-20")
        }),
    }
}

fn parse_time(text: &str) -> Res<NaiveTime> {
    NaiveTime::parse_from_str(text, "%H:%M")
        .map_err(|_| format!("`{text}` is not a time, expected 14:00"))
}

/// Reads a day, a day and a time, or a time alone on `fallback`.
fn parse_when(text: &str, fallback: NaiveDate) -> Res<When> {
    let normalized = text.trim().replace('T', " ");
    let parts: Vec<&str> = normalized.split_whitespace().collect();
    match parts.as_slice() {
        [one] if one.contains(':') => Ok(When::Time(fallback.and_time(parse_time(one)?))),
        [one] => Ok(When::Day(parse_day(one)?)),
        [day, time] => Ok(When::Time(parse_day(day)?.and_time(parse_time(time)?))),
        _ => Err(format!("`{text}` is not a date or a time")),
    }
}

fn parse_duration(text: &str) -> Res<Duration> {
    let bad = || format!("`{text}` is not a duration, expected 45m, 2h, 1h30m, or minutes");
    let mut minutes = 0i64;
    let mut digits = String::new();
    for character in text.trim().chars() {
        match character {
            '0'..='9' => digits.push(character),
            'h' | 'm' | 'd' if !digits.is_empty() => {
                let number: i64 = digits.parse().map_err(|_| bad())?;
                minutes += number
                    * match character {
                        'd' => 1440,
                        'h' => 60,
                        _ => 1,
                    };
                digits.clear();
            }
            _ => return Err(bad()),
        }
    }
    if !digits.is_empty() {
        minutes += digits.parse::<i64>().map_err(|_| bad())?;
    }
    if minutes <= 0 {
        return Err(bad());
    }
    Ok(Duration::minutes(minutes))
}

fn midnight(day: NaiveDate) -> Res<DateTime<Local>> {
    Local
        .from_local_datetime(&day.and_time(NaiveTime::MIN))
        .earliest()
        .ok_or_else(|| format!("{day} has no midnight in the local time zone"))
}

fn encode(text: &str) -> String {
    text.bytes()
        .map(|byte| match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                (byte as char).to_string()
            }
            other => format!("%{other:02X}"),
        })
        .collect()
}

struct Client {
    account: String,
    token: String,
}

impl Client {
    fn open(account: &str) -> Res<Client> {
        let ortie = std::env::var("GCAL_ORTIE").unwrap_or_else(|_| "ortie".to_string());
        let output = Command::new(&ortie)
            .args(["token", "show", "-a", account])
            .output()
            .map_err(|error| format!("cannot run {ortie}: {error}"))?;
        if !output.status.success() {
            let reason = String::from_utf8_lossy(&output.stderr).trim().to_string();
            let reason = if reason.is_empty() {
                "is it signed in?".to_string()
            } else {
                reason
            };
            return Err(format!("no access token for account {account}: {reason}"));
        }
        Ok(Client {
            account: account.to_string(),
            token: String::from_utf8_lossy(&output.stdout).trim().to_string(),
        })
    }

    fn call(
        &self,
        method: &str,
        path: &str,
        query: &[(&str, String)],
        body: Option<&Value>,
    ) -> Res<Value> {
        let mut request = ureq::request(method, &format!("{API}{path}"))
            .set("Authorization", &format!("Bearer {}", self.token));
        for (key, value) in query {
            request = request.query(key, value);
        }
        let result = match body {
            Some(body) => request.send_json(body),
            None => request.call(),
        };
        match result {
            Ok(response) if response.status() == 204 => Ok(Value::Null),
            Ok(response) => response
                .into_json()
                .map_err(|error| format!("unreadable answer: {error}")),
            Err(ureq::Error::Status(code, response)) => {
                let answer: Value = response.into_json().unwrap_or(Value::Null);
                let message = answer["error"]["message"].as_str().unwrap_or("no details");
                Err(format!(
                    "Google answered {code} for account {}: {message}",
                    self.account
                ))
            }
            Err(error) => Err(format!("cannot reach Google: {error}")),
        }
    }

    fn events(
        &self,
        calendar: &str,
        from: DateTime<Local>,
        to: DateTime<Local>,
        text: Option<&str>,
    ) -> Res<Vec<Value>> {
        let mut found = Vec::new();
        let mut page: Option<String> = None;
        loop {
            let mut query = vec![
                ("singleEvents", "true".to_string()),
                ("orderBy", "startTime".to_string()),
                ("maxResults", "250".to_string()),
                ("timeMin", from.to_rfc3339()),
                ("timeMax", to.to_rfc3339()),
            ];
            if let Some(text) = text {
                query.push(("q", text.to_string()));
            }
            if let Some(token) = &page {
                query.push(("pageToken", token.clone()));
            }
            let answer = self.call(
                "GET",
                &format!("/calendars/{}/events", encode(calendar)),
                &query,
                None,
            )?;
            for event in answer["items"].as_array().into_iter().flatten() {
                found.push(simplify(&self.account, calendar, event));
            }
            match answer["nextPageToken"].as_str() {
                Some(token) => page = Some(token.to_string()),
                None => return Ok(found),
            }
        }
    }

    fn event_path(calendar: &str, id: &str) -> String {
        format!("/calendars/{}/events/{}", encode(calendar), encode(id))
    }

    /// The zone typed times are in: the user's, which a calendar set up elsewhere does not share.
    fn time_zone(&self, calendar: &str) -> Res<String> {
        if let Some(zone) = std::env::var("GCAL_TIME_ZONE")
            .ok()
            .filter(|zone| !zone.is_empty())
        {
            return Ok(zone);
        }
        let answer = self.call(
            "GET",
            &format!("/calendars/{}", encode(calendar)),
            &[],
            None,
        )?;
        answer["timeZone"]
            .as_str()
            .map(str::to_string)
            .ok_or_else(|| "the calendar reports no time zone".to_string())
    }
}

/// The fields worth showing, under stable names.
fn simplify(account: &str, calendar: &str, event: &Value) -> Value {
    let all_day = event["start"]["date"].is_string();
    let edge = |side: &str| {
        event[side]["dateTime"]
            .as_str()
            .or(event[side]["date"].as_str())
            .map(str::to_string)
    };
    let guests: Vec<Value> = event["attendees"]
        .as_array()
        .into_iter()
        .flatten()
        .map(|guest| json!({ "email": guest["email"], "response": guest["responseStatus"] }))
        .collect();
    json!({
        "id": event["id"],
        "account": account,
        "calendar": calendar,
        "title": event["summary"].as_str().unwrap_or("(no title)"),
        "start": edge("start"),
        "end": edge("end"),
        "all_day": all_day,
        "location": event["location"],
        "notes": event["description"],
        "meet": event["hangoutLink"],
        "guests": guests,
        "repeats": event["recurrence"].is_array() || event["recurringEventId"].is_string(),
        "series": event["recurringEventId"],
        "rule": event["recurrence"],
        "status": event["status"],
        "link": event["htmlLink"],
    })
}

fn instant(event: &Value, side: &str) -> Option<DateTime<Local>> {
    let text = event[side].as_str()?;
    if event["all_day"].as_bool().unwrap_or(false) {
        midnight(NaiveDate::parse_from_str(text, "%Y-%m-%d").ok()?).ok()
    } else {
        Some(
            DateTime::parse_from_rfc3339(text)
                .ok()?
                .with_timezone(&Local),
        )
    }
}

fn line(event: &Value, with_account: bool) -> String {
    let start = instant(event, "start");
    let day = start
        .map(|start| start.format("%Y-%m-%d %a").to_string())
        .unwrap_or_default();
    let hours = if event["all_day"].as_bool().unwrap_or(false) {
        "all day".to_string()
    } else {
        match (start, instant(event, "end")) {
            (Some(start), Some(end)) => {
                format!("{}-{}", start.format("%H:%M"), end.format("%H:%M"))
            }
            _ => String::new(),
        }
    };
    let mut text = format!(
        "{day}  {hours:<11}  {}",
        event["title"].as_str().unwrap_or("")
    );
    if event["repeats"].as_bool().unwrap_or(false) {
        text.push_str(" (repeats)");
    }
    if with_account {
        text.push_str(&format!("  [{}]", event["account"].as_str().unwrap_or("")));
    }
    format!("{text}  {}", event["id"].as_str().unwrap_or(""))
}

fn detail(event: &Value) -> String {
    let mut text = line(event, true);
    let mut field = |name: &str, value: &Value| {
        if let Some(value) = value.as_str() {
            text.push_str(&format!("\n  {name}: {}", value.replace('\n', "\n    ")));
        }
    };
    field("location", &event["location"]);
    field("meet", &event["meet"]);
    field("notes", &event["notes"]);
    field("series", &event["series"]);
    field("link", &event["link"]);
    for rule in event["rule"].as_array().into_iter().flatten() {
        field("rule", rule);
    }
    for guest in event["guests"].as_array().into_iter().flatten() {
        text.push_str(&format!(
            "\n  guest: {} ({})",
            guest["email"].as_str().unwrap_or(""),
            guest["response"].as_str().unwrap_or("unknown")
        ));
    }
    text
}

fn accounts(cli: &Cli) -> Res<Vec<String>> {
    if let Some(account) = &cli.account {
        return Ok(vec![account.clone()]);
    }
    let listed: Vec<String> = std::env::var("GCAL_ACCOUNTS")
        .unwrap_or_default()
        .split(',')
        .map(|name| name.trim().to_string())
        .filter(|name| !name.is_empty())
        .collect();
    if listed.is_empty() {
        return Err("pass --account, or list the accounts in GCAL_ACCOUNTS".to_string());
    }
    Ok(listed)
}

fn view(cli: &Cli, from: NaiveDate, days: u64, text: Option<&str>) -> Res<()> {
    let end = from
        .checked_add_days(Days::new(days))
        .ok_or("date out of range")?;
    let names = accounts(cli)?;
    let mut events = Vec::new();
    for name in &names {
        events.extend(Client::open(name)?.events(
            &cli.calendar,
            midnight(from)?,
            midnight(end)?,
            text,
        )?);
    }
    events.sort_by_key(|event| instant(event, "start"));
    if cli.json {
        println!("{}", Value::Array(events));
    } else if events.is_empty() {
        println!("No events.");
    } else {
        for event in &events {
            println!("{}", line(event, names.len() > 1));
        }
    }
    Ok(())
}

/// Finds the account holding an event, since an id does not name one.
fn locate(cli: &Cli, id: &str) -> Res<(Client, Value)> {
    let mut missing = String::new();
    for name in accounts(cli)? {
        let client = Client::open(&name)?;
        match client.call("GET", &Client::event_path(&cli.calendar, id), &[], None) {
            Ok(event) => return Ok((client, event)),
            Err(error) if error.contains("answered 404") => missing = error,
            Err(error) => return Err(error),
        }
    }
    Err(format!(
        "no event {id} in calendar {}: {missing}",
        cli.calendar
    ))
}

fn print_event(cli: &Cli, account: &str, event: &Value) {
    let event = simplify(account, &cli.calendar, event);
    if cli.json {
        println!("{event}");
    } else {
        println!("{}", detail(&event));
    }
}

fn day_edge(day: NaiveDate) -> Value {
    json!({ "date": day.format("%Y-%m-%d").to_string() })
}

fn time_edge(time: NaiveDateTime, zone: &str) -> Value {
    json!({ "dateTime": time.format("%Y-%m-%dT%H:%M:%S").to_string(), "timeZone": zone })
}

/// The start and end of an event, an all-day one ending on the day after its last.
fn span(start: &str, end: Option<&str>, duration: Option<&str>, zone: &str) -> Res<(Value, Value)> {
    match parse_when(start, Local::now().date_naive())? {
        When::Day(first) => {
            let last = match (end, duration) {
                (Some(end), _) => match parse_when(end, first)? {
                    When::Day(day) => day,
                    When::Time(_) => {
                        return Err("an all-day event ends on a day, not at a time".to_string())
                    }
                },
                (None, Some(duration)) => {
                    let days = (parse_duration(duration)?.num_minutes() as u64).div_ceil(1440);
                    first
                        .checked_add_days(Days::new(days.max(1) - 1))
                        .ok_or("date out of range")?
                }
                (None, None) => first,
            };
            if last < first {
                return Err("the event ends before it starts".to_string());
            }
            Ok((
                day_edge(first),
                day_edge(last.succ_opt().ok_or("date out of range")?),
            ))
        }
        When::Time(first) => {
            let last = match (end, duration) {
                (Some(end), _) => match parse_when(end, first.date())? {
                    When::Time(time) => time,
                    When::Day(_) => return Err("give --end a time, as --start has one".to_string()),
                },
                (None, Some(duration)) => first + parse_duration(duration)?,
                (None, None) => first + Duration::hours(1),
            };
            if last <= first {
                return Err("the event ends before it starts".to_string());
            }
            Ok((time_edge(first, zone), time_edge(last, zone)))
        }
    }
}

fn rule(args: &NewArgs, all_day: bool) -> Res<Option<String>> {
    let Some(repeat) = &args.repeat else {
        return Ok(None);
    };
    let upper = repeat.to_ascii_uppercase();
    if upper.starts_with("RRULE:") {
        return Ok(Some(upper));
    }
    if upper.starts_with("FREQ=") {
        return Ok(Some(format!("RRULE:{upper}")));
    }
    if !["DAILY", "WEEKLY", "MONTHLY", "YEARLY"].contains(&upper.as_str()) {
        return Err(format!(
            "`{repeat}` is not daily, weekly, monthly, yearly, or an RRULE"
        ));
    }
    let mut text = format!("RRULE:FREQ={upper}");
    if let Some(every) = args.every {
        text.push_str(&format!(";INTERVAL={every}"));
    }
    if let Some(count) = args.count {
        text.push_str(&format!(";COUNT={count}"));
    }
    if let Some(until) = &args.until {
        let day = parse_day(until)?;
        if all_day {
            text.push_str(&format!(";UNTIL={}", day.format("%Y%m%d")));
        } else {
            // the last moment of that local day, which the rule wants in UTC
            let last = midnight(day.succ_opt().ok_or("date out of range")?)? - Duration::seconds(1);
            text.push_str(&format!(
                ";UNTIL={}",
                last.with_timezone(&Utc).format("%Y%m%dT%H%M%SZ")
            ));
        }
    }
    Ok(Some(text))
}

fn meeting() -> Value {
    let id = format!(
        "gcal-{}",
        Utc::now().timestamp_nanos_opt().unwrap_or_default()
    );
    json!({ "createRequest": { "requestId": id, "conferenceSolutionKey": { "type": "hangoutsMeet" } } })
}

fn create(cli: &Cli, args: &NewArgs) -> Res<()> {
    let name = accounts(cli)?.remove(0);
    let client = Client::open(&name)?;
    let zone = client.time_zone(&cli.calendar)?;
    let (start, end) = span(
        &args.start,
        args.end.as_deref(),
        args.duration.as_deref(),
        &zone,
    )?;
    let all_day = start["date"].is_string();
    let mut body = Map::new();
    body.insert("summary".into(), json!(args.title));
    body.insert("start".into(), start);
    body.insert("end".into(), end);
    if let Some(location) = &args.location {
        body.insert("location".into(), json!(location));
    }
    if let Some(notes) = &args.notes {
        body.insert("description".into(), json!(notes));
    }
    if let Some(rule) = rule(args, all_day)? {
        body.insert("recurrence".into(), json!([rule]));
    }
    if !args.invite.is_empty() {
        let guests: Vec<Value> = args
            .invite
            .iter()
            .map(|email| json!({ "email": email }))
            .collect();
        body.insert("attendees".into(), json!(guests));
    }
    if args.meet {
        body.insert("conferenceData".into(), meeting());
    }
    let query = [
        (
            "sendUpdates",
            if args.invite.is_empty() {
                "none"
            } else {
                "all"
            }
            .to_string(),
        ),
        ("conferenceDataVersion", "1".to_string()),
    ];
    let path = format!("/calendars/{}/events", encode(&cli.calendar));
    let event = client.call("POST", &path, &query, Some(&Value::Object(body)))?;
    print_event(cli, &name, &event);
    Ok(())
}

fn edit(cli: &Cli, args: &EditArgs) -> Res<()> {
    let (client, current) = locate(cli, &args.id)?;
    let mut body = Map::new();
    if let Some(title) = &args.title {
        body.insert("summary".into(), json!(title));
    }
    if let Some(location) = &args.location {
        body.insert("location".into(), json!(location));
    }
    if let Some(notes) = &args.notes {
        body.insert("description".into(), json!(notes));
    }
    if args.start.is_some() || args.end.is_some() || args.duration.is_some() {
        let now = simplify(&client.account, &cli.calendar, &current);
        let all_day = now["all_day"].as_bool().unwrap_or(false);
        let (was_start, was_end) = (instant(&now, "start"), instant(&now, "end"));
        let (was_start, was_end) = was_start
            .zip(was_end)
            .ok_or("the event has no readable time")?;
        let shown = |moment: DateTime<Local>| {
            if all_day {
                moment.format("%Y-%m-%d").to_string()
            } else {
                moment.format("%Y-%m-%d %H:%M").to_string()
            }
        };
        let start = args.start.clone().unwrap_or_else(|| shown(was_start));
        // an all-day event ends on the day after its last, and a length restates it
        let kept = (was_end - was_start).num_minutes().max(1).to_string();
        let duration = match (&args.end, &args.duration) {
            (None, None) => Some(kept),
            (_, duration) => duration.clone(),
        };
        let zone = client.time_zone(&cli.calendar)?;
        let (start, end) = span(&start, args.end.as_deref(), duration.as_deref(), &zone)?;
        body.insert("start".into(), start);
        body.insert("end".into(), end);
    }
    if !args.invite.is_empty() {
        let mut guests = current["attendees"].as_array().cloned().unwrap_or_default();
        guests.extend(args.invite.iter().map(|email| json!({ "email": email })));
        body.insert("attendees".into(), json!(guests));
    }
    if args.meet {
        body.insert("conferenceData".into(), meeting());
    }
    if body.is_empty() {
        return Err("nothing to change".to_string());
    }
    let query = [
        (
            "sendUpdates",
            if args.silent { "none" } else { "all" }.to_string(),
        ),
        ("conferenceDataVersion", "1".to_string()),
    ];
    let path = Client::event_path(&cli.calendar, &args.id);
    let event = client.call("PATCH", &path, &query, Some(&Value::Object(body)))?;
    print_event(cli, &client.account, &event);
    Ok(())
}

fn calendars(cli: &Cli) -> Res<()> {
    let mut all = Vec::new();
    for name in accounts(cli)? {
        let answer = Client::open(&name)?.call("GET", "/users/me/calendarList", &[], None)?;
        for calendar in answer["items"].as_array().into_iter().flatten() {
            all.push(json!({
                "account": name,
                "id": calendar["id"],
                "name": calendar["summaryOverride"].as_str().or(calendar["summary"].as_str()),
                "primary": calendar["primary"].as_bool().unwrap_or(false),
                "access": calendar["accessRole"],
                "time_zone": calendar["timeZone"],
            }));
        }
    }
    if cli.json {
        println!("{}", Value::Array(all));
    } else {
        for calendar in &all {
            println!(
                "[{}]  {}{}  ({})  {}",
                calendar["account"].as_str().unwrap_or(""),
                calendar["name"].as_str().unwrap_or(""),
                if calendar["primary"].as_bool().unwrap_or(false) {
                    " (primary)"
                } else {
                    ""
                },
                calendar["access"].as_str().unwrap_or(""),
                calendar["id"].as_str().unwrap_or(""),
            );
        }
    }
    Ok(())
}

fn run(cli: &Cli) -> Res<()> {
    let today = Local::now().date_naive();
    match cli.command.as_ref().unwrap_or(&Cmd::Today) {
        Cmd::Today => view(cli, today, 1, None),
        Cmd::Upcoming { days } => view(cli, today, (*days).max(1), None),
        Cmd::Agenda { from, to } => {
            let (first, last) = (parse_day(from)?, parse_day(to)?);
            if last < first {
                return Err("the last day is before the first".to_string());
            }
            view(cli, first, (last - first).num_days() as u64 + 1, None)
        }
        Cmd::Find { text, from, to } => {
            let first = from.as_deref().map(parse_day).transpose()?.unwrap_or(today);
            let days = match to {
                Some(to) => (parse_day(to)? - first).num_days().max(0) as u64 + 1,
                None => 366,
            };
            view(cli, first, days, Some(text))
        }
        Cmd::Show { id } => {
            let (client, event) = locate(cli, id)?;
            print_event(cli, &client.account, &event);
            Ok(())
        }
        Cmd::Calendars => calendars(cli),
        Cmd::New(args) => create(cli, args),
        Cmd::Edit(args) => edit(cli, args),
        Cmd::Delete { id, silent } => {
            let (client, _) = locate(cli, id)?;
            let query = [(
                "sendUpdates",
                if *silent { "none" } else { "all" }.to_string(),
            )];
            client.call(
                "DELETE",
                &Client::event_path(&cli.calendar, id),
                &query,
                None,
            )?;
            if cli.json {
                println!("{}", json!({ "deleted": id, "account": client.account }));
            } else {
                println!("Deleted {id} from {}.", client.account);
            }
            Ok(())
        }
    }
}

fn main() -> ExitCode {
    match run(&Cli::parse()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("error: {error}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn durations() {
        assert_eq!(parse_duration("45").unwrap().num_minutes(), 45);
        assert_eq!(parse_duration("1h30m").unwrap().num_minutes(), 90);
        assert_eq!(parse_duration("2d").unwrap().num_minutes(), 2880);
        assert!(parse_duration("soon").is_err());
        assert!(parse_duration("0").is_err());
    }

    #[test]
    fn timed_span_defaults_to_an_hour() {
        let (start, end) = span("2026-11-20 14:00", None, None, "Europe/Paris").unwrap();
        assert_eq!(start["dateTime"], "2026-11-20T14:00:00");
        assert_eq!(end["dateTime"], "2026-11-20T15:00:00");
        assert_eq!(end["timeZone"], "Europe/Paris");
    }

    #[test]
    fn end_time_alone_is_on_the_start_day() {
        let (_, end) = span("2026-11-20T14:00", Some("16:30"), None, "UTC").unwrap();
        assert_eq!(end["dateTime"], "2026-11-20T16:30:00");
        assert!(span("2026-11-20 14:00", Some("13:00"), None, "UTC").is_err());
    }

    #[test]
    fn all_day_span_ends_on_the_next_day() {
        let (start, end) = span("2026-11-20", None, None, "UTC").unwrap();
        assert_eq!(start["date"], "2026-11-20");
        assert_eq!(end["date"], "2026-11-21");
        let (_, end) = span("2026-11-20", Some("2026-11-22"), None, "UTC").unwrap();
        assert_eq!(end["date"], "2026-11-23");
        let (_, end) = span("2026-11-20", None, Some("2880"), "UTC").unwrap();
        assert_eq!(end["date"], "2026-11-22");
    }

    #[test]
    fn path_segments_are_escaped() {
        assert_eq!(encode("a b@c.d#e"), "a%20b%40c.d%23e");
    }
}
