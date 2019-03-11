require 'test_helper'

class BeesControllerTest < ActionController::TestCase
  setup do
    @bee = bees(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:bees)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create bee" do
    assert_difference('Bee.count') do
      post :create, bee: { name: @bee.name }
    end

    assert_redirected_to bee_path(assigns(:bee))
  end

  test "should show bee" do
    get :show, id: @bee
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @bee
    assert_response :success
  end

  test "should update bee" do
    patch :update, id: @bee, bee: { name: @bee.name }
    assert_redirected_to bee_path(assigns(:bee))
  end

  test "should destroy bee" do
    assert_difference('Bee.count', -1) do
      delete :destroy, id: @bee
    end

    assert_redirected_to bees_path
  end
end
