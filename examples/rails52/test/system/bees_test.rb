require "application_system_test_case"

class BeesTest < ApplicationSystemTestCase
  setup do
    @bee = bees(:one)
  end

  test "visiting the index" do
    visit bees_url
    assert_selector "h1", text: "Bees"
  end

  test "creating a Bee" do
    visit bees_url
    click_on "New Bee"

    fill_in "Name", with: @bee.name
    click_on "Create Bee"

    assert_text "Bee was successfully created"
    click_on "Back"
  end

  test "updating a Bee" do
    visit bees_url
    click_on "Edit", match: :first

    fill_in "Name", with: @bee.name
    click_on "Update Bee"

    assert_text "Bee was successfully updated"
    click_on "Back"
  end

  test "destroying a Bee" do
    visit bees_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Bee was successfully destroyed"
  end
end
