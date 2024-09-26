---
title: Shar(e)able Updater
date: 2024-09-22T01:09:03-05:00
description:
isStarred: false
---

# Preamble

On my [about me](/aboutme) page, I have a list of "sharables".
I originally stole the template for this list from the [/r/Arlington](https://reddit.com/r/Arlington) discord server.
It contains recently enjoyed media, so that people can get an idea of what type of things you are interested in.

I haven't updated my website in around 2 years, so while I was giving it a refresh I decided to write a script to automatically update these shareables!
I'd like to take a moment to discuss this "refresh", as well as discuss the scripting of the "shareables".

# Refresh

Previously my website was using the [blogdown](https://bookdown.org/yihui/blogdown/) package to let me write websites in R Markdown.
At the time that I was setting this website up (5? years ago), this seemed like a good idea. I was interested in using R for data exploration purposes, and I thought this would be a good way to learn.
However, as I continued to write posts on this and other websites, I realized that I wasn't using any of the R features of R Markdown.
In fact, having to run everything through the blogdown pre-processor was proving very annoying!
(This isn't any fault of the blogdown people, their tooling in R Studio always worked well for me. This has more to do on my reliance on the command line interface for R and my obduracy and unwillingness to use the GUI R Studio)

## Moving to pure Hugo

My blogdown setup used [hugo](https://gohugo.io/) as a static site generator.
I liked the features that hugo provided (shortcodes and templating), and so I decided to continue using it.
Luckily, most of the blogdown setup just _worked_ when I ran the hugo command. Despite using an older directory style than the recent style guides suggested, everything still generated!
I renamed/copied over the `.Rmd` files to `.md` when applicable so that I could edit them in the future. Any documents that I had that relied on R Markdown features I kept around as the rendered `.html` file, so that they could still be accessed.
I also changed the theme template over to the [`hugo-blog-awesome`](https://themes.gohugo.io/themes/hugo-blog-awesome/) theme by Sidharth R.
It's another minimal theme that I believe fits my website well. This was a simple matter of cloning the new theme into the themes folder, and swapping a few settings in the `config.toml` file.
Finally, I switched from having two different repos on Github for the website (one for the source, and one for the compiled "public" folder), to having one repo and running the hugo Github Action to compile it.
A view of the repo for the website is [available on my github](https://github.com/nate601/Website).
I'd like to set up my own CD system self-hosted, but I barely had time to get these thoughts into my editor, much less do something like that right now. 😔

# Sharables [^1]

[^1]:
    Throughout this post I use "Sharable" and "Shareable" interchangeably.
    Both of them show up with squiggly lines under them in my editor, so I'm going to continue using whichever one makes me happiest in the moment.
    Please mentally edit this post to whichever you prefer as well.

There are four categories of "sharables" on my about page.

- Recent Games
- Recent Songs
- Recent Anime
- Recent Books / WebNovels
  - Depending on what I've read recently I'll switch between the two

Of these categories, I'd like two to be automatically updated.
The "recent games" category can update based on the most recent games that I've played, and the "recent songs" can load from my top played from spotify.
Because I don't track the anime that I watch or the books that I read anywhere, there isn't a good way to pull data on these. I could pull the recently viewed on Crunchyroll, or the `.epub` files that I have sent to my Kindle, but neither of these would be an accurate representation.
I share the Crunchyroll account with a few other people, and I often will just send books to the Kindle that I intend on reading, but don't actually end up reading.

## Steam

Steam was the easier of the two sources to implement.
The Steam WebAPI has a `GetRecentlyPlayedGames` endpoint that you can query to return a list of games a player has played within the last 2 weeks.
I store the API key that Steam assigned to me in an environment variable, as well as the steamid of my account.

```python
baseurl = "https://api.steampowered.com/IPlayerService/GetRecentlyPlayedGames/v0001/"
o = {
  "key":env_api_key,
  "steamid": env_steamid
}
resp = httpx.get(baseurl, params=o).json()["response"]["games"]
```

Imagine my surprise when I ran this code and was returned an empty array!
Lately I've been playing modded minecraft on a server with some friends, and I don't track my Minecraft launcher in steam.
This means that in the last 2 weeks I haven't played a single game through steam!
That simply will not do, I need _something_ to put on the website in the sharables field!

Instead of calling that function, I call the `GetOwnedGames` endpoint which retrieves a list of games that the user owns.
Although it isn't documented in valve's WebAPI documentation, the `GetOwnedGames` endpoint also includes an `rtime_last_played` field for each game.
This field gives you the last time that the game was played in seconds since epoch.
I pull the list of all games that I own, and I reverse sort them by `rtime_last_played`. I then return only the first three games.
The actual code is as follows:

```python
baseurl = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/"
o = {"key": api_key, "steamid": steamid, "include_appinfo": True}
resp = httpx.get(baseurl, params=o)
resp = resp.json()
games = resp["response"]["games"]
k = sorted(games, key=lambda game: game["rtime_last_played"], reverse=True)[:3] # Oooh how pythonic...
```

## Spotify

Spotify required a bit more legwork when it came to the auth(entication/orization) process.
Like the steam module, I load in the secrets from environment variables.
Spotify has a `client_id` and `client_secret` assigned to each application that you develop.
You then, as a user, authorize that client to access a certain scope of your account (in this case `user-top-read` for reading the user's most played songs recently)
Once the user authorizes the client, it returns a `UserAuthSecret` that we store on disk.

Once we have this token, then we can query the `https://api.spotify.com/v1/me/top/tracks` endpoint, which returns the user's top tracks for the last time range.
I use the `"short_term"` time range, which I believe is around 4 weeks.

```python
def GetTopTracks(
    access_token: str,
    time_range: Literal["long_term", "medium_term", "short_term"] = "short_term",
    limit: int = 2,
    offset: int = 0,
):
    tracks_endpoint = "https://api.spotify.com/v1/me/top/tracks"
    o = {"type": "tracks", "time_range": time_range, "limit": limit, "offset": offset}
    head = {"Authorization": f"Bearer {access_token}"}
    resp = httpx.get(tracks_endpoint, params=o, headers=head)
```

## Output

Once I pull the data from both of these sources I format it into a list containing a dictionary with two keys `name` and `link`. I then return execution to the `main` module.

A real python programmer would use list comprehension or something here, but I've spent more time on this blog post than I have writing this script.

```python
ret_val = []
for i in resp["items"]:
    ret_val.append(
        {
            "name": f"{i['name']} by {i['artists'][0]['name']}",
            "link": f"{i['external_urls']['spotify']}",
        }
    )
```

In the `main` module I `json.dump` the list into a file for further processing in hugo.

```python
with open("sharables.json", "w") as f:
    json.dump({"steam": gameSharables, "spotify": songSharables}, f)

```

# Importing into Hugo

## Sharable Shortcode

In hugo, I created a shortcode named "sharable" that loads the data the sharables.json file and outputs it into an unordered list.

```md
- Recent Game(s) {{range .Site.Data.sharables.steam}}
  - [{{.name}}]({{.link}}){{else}}
  - No games (on steam) played recently!{{end}}
- Recent Song(s){{range .Site.Data.sharables.spotify}}
  - [{{.name}}]({{.link}}){{else}}
  - No recently played songs (on Spotify) recently!{{end}}
```

Currently this renders into the below:

---

{{% sharable %}}

---

## My age

> The linear passage of time continues to confound me

Another aspect of my life that updates in regards to the passage of time is my biological age.
My website was stating that I was a good 2 years younger than I actually am!
I managed to solve this with another shortcode.
It ended up being kind of a hacky workaround... let me explain.

```md
{{ $t2 := time.AsTime "1999-05-19"}}
{{ $age := time.Now.Sub $t2 }}
{{ $adgeHours := $age.Hours }}
{{ $ageDays := math.Div $adgeHours 8766}}
{{ math.Floor $ageDays }}
```

The `t2` variable is the datetime of my birth, and the `age` variable is the duration between my birth and the time that the website was last updated.
`a~~d~~geHours` is the duration of the `age` in hours, and we divide it by `8766` (the number of hours in a year).
Then we floor the year to get the number of years old I am! As I said: not exactly optimal, but the duration wouldn't let me pull in terms of years!

# Conclusion

After the completion of this project, I have an automatically updating sharables shortcode.
I also have an automatically updating age shortcode.
I'm more familiar with hugo's data formatting, which is another plus!
I'd never had to use it before, but it's pretty neat.
Originally, I was going to format the markdown in python, and export that (which is still technicially done).
But knowing that hugo can do that kind of formatting on arbitrary data files is very cool!

```python
filename = "updatableSharables.md"
with open(filename, "w") as f:
    f.write("* Recent Game(s)\n")
    for game in gameSharables:
        f.write(f" * ({game['name']})[{game['link']}]\n")
    f.write("* Recent Song(s)\n")
    for song in songSharables:
        f.write(f" * ({song['name']})[{song['link']}]\n")
```

I didn't really gain any new python knowledge from this project, as this type of API access is what I use python for at my work. The code that I used wasn't very pythonic at places.
(e.g. I could've used list comprehension in several places instead of for loops.)
Additionally it wasn't very performant.
(e.g. I could've kept the same instance of the httpx client passed around the modules).
I don't really know who that efficiency gain would be for though.
Maybe knowing that I can make it more efficient and not doing so is some kind of zen.
Insert shrugging emoji here...
