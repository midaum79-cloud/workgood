# config/sitemap.rb
# Run: rake sitemap:refresh

require "rubygems"
require "sitemap_generator"

SitemapGenerator::Sitemap.default_host = "https://www.workgood.co.kr"
SitemapGenerator::Sitemap.public_path  = "public/"
SitemapGenerator::Sitemap.sitemaps_path = ""
SitemapGenerator::Sitemap.create_index = false

SitemapGenerator::Sitemap.create do
  # 메인 공개 페이지
  add "/",         changefreq: "weekly",  priority: 1.0
  add "/login",    changefreq: "monthly", priority: 0.5
  add "/signup",   changefreq: "monthly", priority: 0.6
  add "/guide",    changefreq: "monthly", priority: 0.8
  add "/terms",    changefreq: "yearly",  priority: 0.3
  add "/privacy",  changefreq: "yearly",  priority: 0.3

  # 로그인이 필요한 내부 페이지는 크롤링 대상에서 제외
  # /projects, /vendors, /notifications 등 인증 필요 페이지 제외
end
