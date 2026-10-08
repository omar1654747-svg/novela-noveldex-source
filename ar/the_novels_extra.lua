id       = "the_novels_extra"
name     = "The Novel's Extra - NovelLunar"
version  = "2.0.0"
baseUrl  = "https://novellunar.com"
language = "ar"
icon     = "https://img.novellunar.com/the-novels-extra.webp"
content_type = "novel"

local BOOK_URL = baseUrl .. "/novel/the-novels-extra"
local function absUrl(href)
  if not href or href == "" then return "" end
  if string_starts_with(href, "http") then return href end
  return url_resolve(baseUrl, href)
end
local function fetchPage(url)
  local r = http_get(url, { headers = { ["Accept-Language"] = "ar,en;q=0.8" } })
  if r and r.success then return r.body end
  return nil
end
local function bookItem()
  return { title = "The Novel's Extra", url = BOOK_URL, cover = icon }
end

function getCatalogList(index)
  if (index or 0) > 0 then return { items = {}, hasNext = false } end
  return { items = { bookItem() }, hasNext = false }
end

function getCatalogSearch(index, query)
  if (index or 0) > 0 then return { items = {}, hasNext = false } end
  local q = string_clean(query or "")
  if q == "" or string.find(q, "novel", 1, true) or string.find(q, "extra", 1, true) or string.find(q, "كومبارس", 1, true) or string.find(q, "الرواية", 1, true) then
    return { items = { bookItem() }, hasNext = false }
  end
  return { items = {}, hasNext = false }
end

function getBookTitle(bookUrl)
  local body = fetchPage(bookUrl)
  if not body then return "The Novel's Extra" end
  local el = html_select_first(body, "h1")
  return el and string_clean(el.text):gsub("%s*رواية%s*$", "") or "The Novel's Extra"
end

function getBookCoverImageUrl(bookUrl)
  local body = fetchPage(bookUrl)
  local value = body and html_attr(body, "meta[property='og:image']", "content") or ""
  return value ~= "" and value or icon
end

function getBookDescription(bookUrl)
  local body = fetchPage(bookUrl)
  local value = body and html_attr(body, "meta[name='description']", "content") or ""
  return value ~= "" and string_clean(value) or nil
end

function getBookStatus(bookUrl)
  local body = fetchPage(bookUrl)
  if not body then return nil end
  local text = string_clean(html_text(body))
  if string.find(text, "جارية", 1, true) then return "Ongoing" end
  if string.find(text, "مكتملة", 1, true) then return "Completed" end
  return nil
end

function getBookRating(bookUrl)
  local body = fetchPage(bookUrl)
  local text = body and string.match(body, "([0-9]+%.[0-9]+)") or nil
  return text
end

local function parseChapters(body)
  local chapters = {}
  -- NovelLunar renders the chapter tab client-side. The page exposes the
  -- total count in its serialized novel data, so construct stable chapter URLs.
  local total = tonumber(string.match(body or "", "totalChapters[\"]*:%s*(%d+)")) or 481
  for number = 1, total do
    table.insert(chapters, {
      title = "Chapter " .. tostring(number),
      url = baseUrl .. "/novel/the-novels-extra/chapter/" .. tostring(number)
    })
  end
  return chapters
end

function parsePage(bookUrl, page)
  if (page or 1) > 1 then return { chapters = {}, totalPages = 1 } end
  local body = fetchPage(bookUrl)
  if not body then return { chapters = {}, totalPages = 1 } end
  return { chapters = parseChapters(body), totalPages = 1 }
end

function getChapterList(bookUrl)
  return parsePage(bookUrl, 1).chapters
end

function getChapterListHash(bookUrl)
  local body = fetchPage(bookUrl)
  local first = body and html_select_first(body, "a[href*='/novel/the-novels-extra/chapter/']")
  return first and first.href or nil
end

function getChapterText(html, url)
  local cleaned = html_remove(html, "script", "style", "nav", ".chapter-header", ".chapter-bottom-bar")
  local article = html_select_first(cleaned, "article")
  if not article then return "" end
  return string_trim(html_text(article.html))
end
