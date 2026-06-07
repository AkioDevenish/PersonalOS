const q = "Tycho Awake";
fetch(`https://www.youtube.com/results?search_query=${encodeURIComponent(q)}`)
  .then(r => r.text())
  .then(html => {
    const match = html.match(/"videoId":"([^"]{11})"/);
    console.log(match ? match[1] : "not found");
  });
