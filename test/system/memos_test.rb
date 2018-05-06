# frozen_string_literal: true

require 'application_system_test_case'

class MemosTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  setup do
    user = users(:one)
    user.confirm
    sign_in user
    @memo = memos(:one)
  end

  test 'visiting the index' do
    visit memos_url
    assert_selector 'h1', text: 'Memos'
  end

  test 'creating a Memo' do
    visit memos_url
    click_on 'New Memo'

    fill_in 'Category', with: @memo.category
    fill_in 'Content', with: @memo.content
    fill_in 'Create From', with: @memo.create_from
    fill_in 'Info', with: @memo.info
    fill_in 'Price', with: @memo.price
    fill_in 'Tags', with: @memo.tags
    fill_in 'User', with: @memo.user_id
    click_on 'Create Memo'

    assert_text 'Memo was successfully created'
    click_on 'Back'
  end

  test 'updating a Memo' do
    visit memos_url
    click_on 'Edit', match: :first

    fill_in 'Category', with: @memo.category
    fill_in 'Content', with: @memo.content
    fill_in 'Create From', with: @memo.create_from
    fill_in 'Info', with: @memo.info
    fill_in 'Price', with: @memo.price
    fill_in 'Tags', with: @memo.tags
    fill_in 'User', with: @memo.user_id
    click_on 'Update Memo'

    assert_text 'Memo was successfully updated'
    click_on 'Back'
  end

  test 'destroying a Memo' do
    visit memos_url
    page.accept_confirm do
      click_on 'Destroy', match: :first
    end

    assert_text 'Memo was successfully destroyed'
  end
end
