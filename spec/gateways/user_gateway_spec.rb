require 'spec_helper'

class UserGatewaySpec < Minitest::Spec

  let(:backend) { FakeBackend.new }
  let(:gateway) { Gateways::UserGateway.new(backend) }
  let(:user) { build_user :login_count => 23 }
  let(:add_user) { gateway.add(user) }

  describe "add" do
    it "ensures the added object is a User Entity" do
      assert_failure { gateway.add(23) }
    end

    describe "with an already added user" do
      let(:user) { build_user(:uid => 1) }

      it "fails" do
        assert_failure { gateway.add(user) }
      end
    end

    it "returns the id of the inserted quote on success" do
      user_uid = add_user

      assert_equal 'test_user_uid', user_uid
    end

    it "serializes the user and delegates it to the backend" do
      user_uid  = add_user
      result = gateway.get(user_uid)

      assert_equal result.nickname, user.nickname
      assert_equal result.email, user.email
      assert_equal result.auth_key, user.auth_key
      assert_empty result.favorites
      assert_empty result.added
      assert_equal false, result.terms_accepted?
      assert_equal nil, result.last_login_time
      assert_equal nil, result.last_login_address
      assert_equal 23, result.login_count
    end
  end

  describe "get" do
    it "returns nil if the backend returns nil" do
      assert_nil gateway.get('not_a_stored_id')
    end
  end

  describe "fetch" do
    it "returns nil if no user is found" do
      assert_nil gateway.fetch('nickname')
    end

    it "returns the user with the given nickname" do
      add_user

      fetched_user = gateway.fetch(user.nickname)
      assert_equal user.nickname, fetched_user.nickname
      assert_equal user.email, fetched_user.email
      assert_equal user.auth_key, fetched_user.auth_key
    end
  end

  describe "update" do
    describe "without a persisted object" do
      it "fails" do
        assert_failure { gateway.update(user) }
      end
    end

    it "updates any changed attributes" do
      user_uid = add_user
      gateway.update(updated_user(user_uid))
      result = gateway.get(user_uid)

      refute_equal user, result
      assert_equal user_uid, result.uid
      assert_equal user.nickname, result.nickname
      assert_equal 'new email', result.email
    end
  end

  describe 'publish_quote' do
    let(:published_quote_uid) { 13 }

    describe 'without a persisted object' do
      let(:wrong_user_uid) { 90 }

      it 'fails' do
        assert_failure do
          gateway.publish_quote(wrong_user_uid, published_quote_uid)
        end
      end
    end

    it 'adds the published quote to the :added array for the given user' do
      user_uid = add_user
      gateway.publish_quote(user_uid, published_quote_uid)
      result = gateway.get(user_uid)

      assert_includes result.added, published_quote_uid
    end
  end

  describe "all" do
    let(:user_two) { Entities::User.new('2', '2', '2') }
    let(:user_three) { Entities::User.new('3', '3', '3') }
    let(:users)      { [user, user_two, user_three] }

    it "returns an empty array if the backend is empty" do
      assert_empty gateway.all
    end

    it "returns all items in the backend" do
      users.each {|user| gateway.add(user)}
      result = gateway.all

      assert_equal 3,           result.size
      assert_equal "nickname",  result[0].nickname
      assert_equal "2",         result[1].nickname
      assert_equal "3",         result[2].nickname
    end
  end

  describe "delete" do
    describe "without a persisted object" do
      it "fails" do
        assert_failure { gateway.delete(user.uid) }
      end
    end

    it "removes the user associated with the given uid" do
      uid = gateway.add(user)
      gateway.delete(uid)

      assert_nil gateway.get(uid)
    end
  end

  describe "toggle_favorite" do
    describe "without a persisted user" do
      it "fails" do
        assert_failure { gateway.toggle_favorite(user.uid, '23') }
      end
    end

    it "adds or removes a quote uid to/from the user's favorites" do
      uid = gateway.add(user)
      quote_uid = '23'

      user = gateway.get(uid)
      assert_equal false, user.favorites.include?(quote_uid)

      gateway.toggle_favorite(uid, quote_uid)
      user = gateway.get(uid)
      assert_equal true, user.favorites.include?(quote_uid)

      gateway.toggle_favorite(uid, quote_uid)
      user = gateway.get(uid)
      assert_equal false, user.favorites.include?(quote_uid)
    end
  end

  def updated_user(uid)
    build_user(
      :uid => uid,
      :email => 'new email'
    )
  end

  class FakeBackend

    def initialize
      @memory = []
    end

    def insert(user)
      user[:uid] = 'test_user_uid'

      @memory << convert_booleans(user)
      user[:uid]
    end

    def get(uid)
      @memory.select { |u| u[:uid] == uid }.first
    end

    def fetch(nickname)
      @memory.select { |u| u[:nickname] == nickname }.first
    end

    def update(user)
      @memory.delete_if {|u| u[:uid] == user[:uid]}
      @memory << convert_booleans(user)
    end

    def all
      @memory
    end

    def delete(uid)
      @memory.delete_if {|u| u[:uid] == uid}
    end

    def convert_booleans(user)
      if user[:terms] == true
        user[:terms] = "1"
      else
        user[:terms] = "0"
      end

      user
    end

  end
end
