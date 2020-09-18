# frozen_string_literal: true

module ApplicationHelper
  def full_title(page_title = '')
    base_title = I18n.t(:'nav.site_name')
    if page_title.empty?
      base_title
    else
      "#{page_title} | #{base_title}"
    end
  end

  def nav_link_to(name, path, link_options: {})
    active = request.path == path
    nav_item_html_class = active ? 'nav-item active' : 'nav-item'
    tag.li class: nav_item_html_class do
      link_to path, class: 'nav-link', **link_options do
        if active
          h(name) + tag.span('(current)', class: 'sr-only')
        else
          name
        end
      end
    end
  end
end
