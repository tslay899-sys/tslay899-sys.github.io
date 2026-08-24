(() => {
  const logs = Array.isArray(window.LEARNING_LOGS)
    ? [...window.LEARNING_LOGS].sort((a, b) => b.date.localeCompare(a.date))
    : [];

  const state = { query: "", tag: "全部" };
  const container = document.querySelector("#log-container");
  const emptyState = document.querySelector("#empty-state");
  const resultCount = document.querySelector("#result-count");
  const searchInput = document.querySelector("#search-input");
  const tagFilters = document.querySelector("#tag-filters");

  const dateFormatter = new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "long",
    day: "numeric",
    weekday: "short"
  });

  function parseDate(date) {
    return new Date(`${date}T00:00:00`);
  }

  function formatDate(date) {
    return dateFormatter.format(parseDate(date));
  }

  function calculateStreak(items) {
    if (!items.length) return 0;
    const days = [...new Set(items.map((item) => item.date))]
      .map(parseDate)
      .sort((a, b) => b - a);
    let streak = 1;
    for (let index = 1; index < days.length; index += 1) {
      const difference = Math.round((days[index - 1] - days[index]) / 86400000);
      if (difference !== 1) break;
      streak += 1;
    }
    return streak;
  }

  function normalizeImagePath(path) {
    let normalized = String(path || "").trim().replace(/\\/g, "/");
    normalized = normalized.replace(/^\.\.\//, "").replace(/^\.\//, "");
    if (!normalized.startsWith("media/") || normalized.includes("../")) return null;
    return normalized;
  }

  function appendRichLine(element, line) {
    const imagePattern = /!\[([^\]]*)\]\(([^)\n]+)\)/g;
    let cursor = 0;
    let match;

    while ((match = imagePattern.exec(line)) !== null) {
      if (match.index > cursor) {
        element.appendChild(document.createTextNode(line.slice(cursor, match.index)));
      }

      const source = normalizeImagePath(match[2]);
      if (source) {
        const image = document.createElement("img");
        image.className = "inline-log-image";
        image.src = source;
        image.alt = match[1] || "学习日志配图";
        image.loading = "lazy";
        element.appendChild(image);
      } else {
        element.appendChild(document.createTextNode(match[0]));
      }
      cursor = imagePattern.lastIndex;
    }

    if (cursor < line.length) {
      element.appendChild(document.createTextNode(line.slice(cursor)));
    }
  }

  function appendText(element, text) {
    const lines = String(text || "").split(/\r?\n/);
    let listStack = [];

    lines.forEach((rawLine) => {
      const line = rawLine.trim();
      if (!line) {
        listStack = [];
        return;
      }

      const listMatch = rawLine.match(/^(\s*)[-*]\s+(.*)$/);
      if (listMatch) {
        const spaces = listMatch[1].replace(/\t/g, "  ").length;
        let level = Math.floor(spaces / 2);

        if (!listStack.length) {
          const rootList = document.createElement("ul");
          element.appendChild(rootList);
          listStack.push(rootList);
        }

        level = Math.min(level, listStack.length);
        while (listStack.length <= level) {
          const parentList = listStack[listStack.length - 1];
          const parentItem = parentList.lastElementChild;
          if (!parentItem) break;
          const nestedList = document.createElement("ul");
          parentItem.appendChild(nestedList);
          listStack.push(nestedList);
        }
        listStack = listStack.slice(0, level + 1);

        const item = document.createElement("li");
        appendRichLine(item, listMatch[2]);
        listStack[listStack.length - 1].appendChild(item);
        return;
      }

      listStack = [];
      const paragraph = document.createElement("p");
      appendRichLine(paragraph, line);
      element.appendChild(paragraph);
    });
  }

  function createContentBlock(label, text, className = "") {
    if (!text) return null;
    const block = document.createElement("section");
    block.className = `content-block ${className}`.trim();
    const heading = document.createElement("h3");
    heading.textContent = label;
    block.appendChild(heading);
    appendText(block, text);
    return block;
  }

  function createCard(log, isLatest) {
    const article = document.createElement("article");
    article.className = "log-card";

    const header = document.createElement("header");
    header.className = "card-header";
    const headingWrap = document.createElement("div");
    const time = document.createElement("time");
    time.className = "log-date";
    time.dateTime = log.date;
    time.textContent = formatDate(log.date);
    const title = document.createElement("h3");
    title.className = "log-title";
    title.textContent = log.title;
    headingWrap.append(time, title);
    header.appendChild(headingWrap);

    if (isLatest) {
      const badge = document.createElement("span");
      badge.className = "latest-badge";
      badge.textContent = "最新";
      header.appendChild(badge);
    }

    const content = document.createElement("div");
    content.className = "card-content";
    [
      createContentBlock("今日学习", log.learned),
      createContentBlock("收获与思考", log.insight),
      createContentBlock("下一步", log.next),
      createContentBlock("今日一句", log.motto, "motto-block"),
      createContentBlock("今日推荐曲目", log.recommendation, "music-block")
    ].filter(Boolean).forEach((block) => content.appendChild(block));

    if (log.image) {
      const image = document.createElement("img");
      image.className = "log-image";
      image.src = log.image;
      image.alt = log.imageAlt || `${log.title}的配图`;
      image.loading = "lazy";
      content.appendChild(image);
    }

    article.append(header, content);

    if (Array.isArray(log.tags) && log.tags.length) {
      const tags = document.createElement("footer");
      tags.className = "card-tags";
      log.tags.forEach((tag) => {
        const item = document.createElement("span");
        item.className = "card-tag";
        item.textContent = tag;
        tags.appendChild(item);
      });
      article.appendChild(tags);
    }

    return article;
  }

  function matches(log) {
    const searchable = [
      log.date,
      log.title,
      log.learned,
      log.insight,
      log.next,
      log.motto,
      ...(log.tags || [])
    ].join(" ").toLocaleLowerCase("zh-CN");
    const matchesQuery = searchable.includes(state.query.toLocaleLowerCase("zh-CN"));
    const matchesTag = state.tag === "全部" || (log.tags || []).includes(state.tag);
    return matchesQuery && matchesTag;
  }

  function renderLogs() {
    const visibleLogs = logs.filter(matches);
    container.replaceChildren();
    visibleLogs.forEach((log) => container.appendChild(createCard(log, log === logs[0])));
    emptyState.hidden = visibleLogs.length > 0;
    resultCount.textContent = `显示 ${visibleLogs.length} / ${logs.length} 篇`;
  }

  function renderFilters() {
    const tags = ["全部", ...new Set(logs.flatMap((log) => log.tags || []))];
    tags.forEach((tag) => {
      const button = document.createElement("button");
      button.className = "filter-button";
      button.type = "button";
      button.textContent = tag;
      button.setAttribute("aria-pressed", String(tag === state.tag));
      button.addEventListener("click", () => {
        state.tag = tag;
        tagFilters.querySelectorAll("button").forEach((item) => {
          item.setAttribute("aria-pressed", String(item === button));
        });
        renderLogs();
      });
      tagFilters.appendChild(button);
    });
  }

  function setupTheme() {
    const button = document.querySelector("#theme-button");
    const icon = document.querySelector("#theme-icon");
    let savedTheme = null;
    try {
      savedTheme = localStorage.getItem("learning-log-theme");
    } catch (_) {
      savedTheme = null;
    }
    const preferredTheme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    document.documentElement.dataset.theme = savedTheme || preferredTheme;
    icon.textContent = document.documentElement.dataset.theme === "dark" ? "☀" : "◐";

    button.addEventListener("click", () => {
      const nextTheme = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
      document.documentElement.dataset.theme = nextTheme;
      icon.textContent = nextTheme === "dark" ? "☀" : "◐";
      try {
        localStorage.setItem("learning-log-theme", nextTheme);
      } catch (_) {
        // 本地文件预览可能禁止存储，但本次访问仍可正常切换主题。
      }
    });
  }

  document.querySelector("#total-count").textContent = logs.length;
  document.querySelector("#streak-count").textContent = calculateStreak(logs);
  document.querySelector("#latest-date").textContent = logs.length ? logs[0].date.slice(5).replace("-", ".") : "—";
  document.querySelector("#current-year").textContent = new Date().getFullYear();

  searchInput.addEventListener("input", (event) => {
    state.query = event.target.value.trim();
    renderLogs();
  });

  setupTheme();
  renderFilters();
  renderLogs();
})();
