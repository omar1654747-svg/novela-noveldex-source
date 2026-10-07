id       = "the_novels_extra"
name     = "The Novel’s Extra"
version  = "1.0.0"
baseUrl  = "https://noveldex.io"
language = "en"
icon     = "https://noveldex.io/uploads/settings/logo-9f6ca6403bb40c476fb1c57fa981d6bc.webp"
content_type = "novel"

local BROWSER_HEADERS = {
  ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  ["Accept-Language"] = "en-US,en;q=0.9",
}
local _pageCache = {}
local _seriesIdCache = {}
local FIXED_BOOK_URL = baseUrl .. "/series/novel/the-novels-extra"

local function absUrl(href)
  if not href or href == "" then return "" end
  if string_starts_with(href, "http") then return href end
  if string_starts_with(href, "//") then return "https:" .. href end
  return url_resolve(baseUrl, href)
end

local function fetch(url)
  local r = http_get(url, { headers = BROWSER_HEADERS })
  if r and r.success then return r.body end
  return nil
end

local function fetchPage(url)
  if _pageCache[url] then return _pageCache[url] end
  local body = fetch(url)
  if body then _pageCache[url] = body end
  return body
end

local function novelSlug(bookUrl)
  return string.match(bookUrl or "", "/series/novel/([^/?#]+)")
end

-- Next.js embeds the internal series id in the server-rendered page. The id
-- is required by NovelDex's public chapter JSON endpoint.
local function getSeriesId(bookUrl)
  local slug = novelSlug(bookUrl)
  if not slug then return nil end
  if _seriesIdCache[slug] then return _seriesIdCache[slug] end
  local body = fetchPage(baseUrl .. "/series/novel/" .. slug)
  if not body then return nil end
  local marker = "\\\"series\\\":{\\\"id\\\":\\\""
  local start = string.find(body, marker, 1, true)
  if not start then return nil end
  start = start + #marker
  local finish = string.find(body, "\\\"", start, true)
  if not finish then return nil end
  local idValue = string.sub(body, start, finish - 1)
  if idValue ~= "" then _seriesIdCache[slug] = idValue end
  return idValue
end

local function coverUrl(src)
  if not src or src == "" then return "" end
  -- Keep the site's optimized image URL; it is a stable HTTPS cover URL.
  return absUrl(src)
end

local function parseCards(body)
  local items, seen = {}, {}
  for _, card in ipairs(html_select(body, "[data-card-set-item]")) do
    local link = html_select_first(card.html, "a[href*='/series/novel/']")
    local titleEl = html_select_first(card.html, "h3")
    if link and titleEl then
      local url = absUrl(link.href)
      local title = string_clean(titleEl.text)
      if url ~= "" and title ~= "" and not seen[url] then
        seen[url] = true
        local image = html_select_first(card.html, "img")
        local cover = image and coverUrl(image.src) or ""
        local item = { title = title, url = url, cover = cover }
        local ratingEl = html_select_first(card.html, "span.text-amber-500")
        if ratingEl and string_trim(ratingEl.text) ~= "" then
          item.rating = string_trim(ratingEl.text) .. "/10"
        end
        table.insert(items, item)
      end
    end
  end
  return items
end

local function fixedBookItem()
  local title = getBookTitle(FIXED_BOOK_URL) or "The Novel’s Extra"
  return {
    title = title,
    url = FIXED_BOOK_URL,
    cover = getBookCoverImageUrl(FIXED_BOOK_URL) or "",
  }
end

function getCatalogList(index)
  if (index or 0) > 0 then return { items = {}, hasNext = false } end
  return { items = { fixedBookItem() }, hasNext = false }
end

function getCatalogSearch(index, query)
  if (index or 0) > 0 then return { items = {}, hasNext = false } end
  local q = string_clean(query or "")
  if q == "" or string.find(string_clean("The Novel’s Extra"), q, 1, true) or string.find(string_clean("The Novels Extra"), q, 1, true) then
    return { items = { fixedBookItem() }, hasNext = false }
  end
  return { items = {}, hasNext = false }
end

function getBookTitle(bookUrl)
  local body = fetchPage(bookUrl)
  local el = body and html_select_first(body, "[data-series-title] h1")
  return el and string_clean(el.text) or nil
end

function getBookCoverImageUrl(bookUrl)
  local body = fetchPage(bookUrl)
  if not body then return nil end
  local src = html_attr(body, "meta[property='og:image']", "content")
  return src ~= "" and absUrl(src) or nil
end

function getBookDescription(bookUrl)
  local body = fetchPage(bookUrl)
  if not body then return nil end
  local meta = html_attr(body, "meta[name='description']", "content")
  return meta ~= "" and string_trim(meta) or nil
end

function getBookGenres(bookUrl)
  local body = fetchPage(bookUrl)
  if not body then return {} end
  local genres, seen = {}, {}
  for _, a in ipairs(html_select(body, "a[href*='/genres/'], a[href*='genre=']")) do
    local value = string_clean(a.text)
    if value ~= "" and not seen[value] then
      seen[value] = true
      table.insert(genres, value)
    end
  end
  return genres
end

function getBookStatus(bookUrl)
  local body = fetchPage(bookUrl)
  if not body then return nil end
  for _, el in ipairs(html_select(body, "[data-series-header] span, [data-series-header] div")) do
    local value = string_trim(el.text)
    if string.find(value, "ONGOING", 1, true) then return "ONGOING" end
    if string.find(value, "COMPLETED", 1, true) then return "COMPLETED" end
    if string.find(value, "HIATUS", 1, true) then return "HIATUS" end
    if string.find(value, "CANCELLED", 1, true) then return "CANCELLED" end
  end
  return nil
end

function getBookRating(bookUrl)
  local body = fetchPage(bookUrl)
  if not body then return nil end
  local meta = html_attr(body, "meta[itemprop='ratingValue']", "content")
  return meta ~= "" and (meta .. "/10") or nil
end

local function parseChapterLinks(body)
  local chapters, seen = {}, {}
  for _, a in ipairs(html_select(body, "a[href*='/chapter/']")) do
    local url = absUrl(a.href)
    local title = string_clean(a.text)
    if url ~= "" and title ~= "" and not seen[url] then
      seen[url] = true
      table.insert(chapters, { title = title, url = url })
    end
  end
  return chapters
end

-- NovelDex exposes 100 chapters per series page and links the remaining pages
-- as /series/novel/<slug>?page=N. NoveLA consumes this paginated contract.
function parsePage(bookUrl, page)
  page = page or 1
  local separator = string.find(bookUrl, "?", 1, true) and "&" or "?"
  local url = bookUrl .. separator .. "page=" .. tostring(page)
  local body = fetchPage(url)
  if not body then return { chapters = {}, totalPages = 1 } end
  local totalPages = 1
  for _, a in ipairs(html_select(body, "a[href*='?page='], a[href*='&page=']")) do
    local n = string.match(a.href or "", "[?&]page=(%d+)")
    if n and tonumber(n) > totalPages then totalPages = tonumber(n) end
  end
  return { chapters = parseChapterLinks(body), totalPages = totalPages }
end

function getChapterList(bookUrl)
  return parsePage(bookUrl, 1).chapters
end

function getChapterListHash(bookUrl)
  local body = fetch(bookUrl)
  if not body then return nil end
  local first = html_select_first(body, "a[href*='/chapter/']")
  return first and first.href or nil
end

function getChapterText(html, url)
  local slug = novelSlug(url)
  local number = string.match(url or "", "/chapter/(%d+)")
  if not slug or not number then return "" end
  local seriesId = getSeriesId(baseUrl .. "/series/novel/" .. slug)
  if not seriesId then return "" end
  local previous = tonumber(number) - 1
  local endpoint = baseUrl .. "/api/chapters/next?seriesId=" .. url_encode(seriesId)
      .. "&afterNumber=" .. tostring(previous) .. "&limit=1"
  local body = fetch(endpoint)
  if not body then return "" end
  local ok, data = pcall(json_parse, body)
  if not ok or not data or not data.chapters or not data.chapters[1] then return "" end
  local content = data.chapters[1].content or ""
  content = html_remove(content, "script", "style", "h1")
  return string_trim(html_text(content))
end
