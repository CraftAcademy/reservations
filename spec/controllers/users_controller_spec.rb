require 'spec_helper'

shared_examples_for 'page success' do
  it { is_expected.to respond_with(:success) }
  it { is_expected.not_to set_flash }
end

shared_examples_for 'access denied' do
  it { is_expected.to redirect_to(root_url) }
  it { is_expected.to set_flash }
end

describe UsersController, type: :controller do
  before(:all) do
    @app_config = FactoryGirl.create(:app_config)
  end
  let!(:user) { FactoryGirl.create(:user) }

  context 'with admin user' do
    before do
      sign_in FactoryGirl.create(:admin)
    end
    describe 'GET index' do
      let!(:banned) { FactoryGirl.create(:banned) }
      let!(:other_user) { FactoryGirl.create(:user) }
      before { get :index }
      it_behaves_like 'page success'
      it { is_expected.to render_template(:index) }
      context 'without show banned' do
        it 'should assign users to all active users' do
          expect(assigns(:users).include?(other_user)).to be_truthy
          expect(assigns(:users).include?(banned)).to be_falsey
        end
      end
      context 'with show banned' do
        before { get :index, show_banned: true }
        it 'should assign users to all users' do
          expect(assigns(:users).include?(banned)).to be_truthy
        end
      end
    end
    describe 'GET show' do
      before { get :show, id: user }
      it_behaves_like 'page success'
      it { is_expected.to render_template(:show) }

      context 'with banned user' do
        before { get :show, id: FactoryGirl.create(:banned) }
        it { is_expected.to respond_with(:success) }
        it { is_expected.to set_flash }
      end
    end

    describe 'POST quick_new' do
      context 'possible netid provided' do
        before { post :quick_new, format: :js, possible_netid: 'csw3' }
        it 'should assign @user to the possible netid' do
          expect(assigns(:user).attributes).to\
            eq(User.new(User.search_ldap('csw3')).attributes)
        end
      end
    end

    describe 'POST quick_create' do
      before(:each) do
        short_form_attrs = [:username, :first_name, :last_name, :phone,
                            :email, :affiliation]

        # only pass in the short form attributes
        user_params = FactoryGirl.attributes_for(:user) do |attrs|
          attrs.keep_if { |k, _| short_form_attrs.include? k }
        end

        post :quick_create, format: :js, user: user_params
      end

      # clear database
      after(:all) do
        User.delete_all
      end

      shared_examples_for 'sets cart reserver' do
        it 'to new user' do
          expect(session[:cart].reserver_id).to eq(assigns(:user).id)
        end
      end

      context 'not using CAS' do
        it 'creates valid user' do
          # test using ActiveModel validation since we load Rails without CAS
          # enabled
          expect(assigns(:user)).to be_valid
        end

        it_behaves_like 'sets cart reserver'
      end

      context 'using CAS' do
        # set the environment variable and reload User class
        around(:example) do |example|
          env_wrapper('CAS_AUTH' => '1') { example.run }
        end

        it 'creates valid user' do
          # test by checkin the cas_login attribute directly since our
          # ActiveModel validations won't catch it
          expect(assigns(:user).cas_login).not_to be_nil
        end

        it_behaves_like 'sets cart reserver'
      end
    end

    describe 'GET new' do
      before { get :new }
      context 'possible netid not provided' do
        it 'should assign @user to a new user' do
          expect(assigns(:user).attributes).to eq(User.new.attributes)
        end
      end
      it 'should assign @can_edit_username to true' do
        expect(assigns(:can_edit_username)).to be_truthy
      end
      it_behaves_like 'page success'
      it { is_expected.to render_template(:new) }

      context 'when new user registration is disabled' do
        before do
          AppConfig.first.update_attributes(enable_new_users: false)
          get :new
        end

        it_behaves_like 'page success'
        it { is_expected.to render_template(:new) }
      end
    end
    describe 'POST create' do
      shared_examples_for 'saves user' do
        it 'successfully' do
          expect(User.find(assigns(:user).id)).not_to be_nil
        end
      end

      context 'with correct params' do
        before do
          @user_attributes = FactoryGirl.attributes_for(:user)
          post :create, user: @user_attributes
        end

        it_behaves_like 'saves user'
      end

      context 'with incorrect params' do
        before do
          @bad_attributes = FactoryGirl.attributes_for(:user, first_name: '')
          post :create, user: @bad_attributes
        end

        it 'should not save the user' do
          expect(assigns(:user).save).to be_falsey
        end
      end

      context 'when new user registration is disabled and correct params' do
        before do
          AppConfig.first.update_attributes(enable_new_users: false)
          @user_attributes = FactoryGirl.attributes_for(:user)
          post :create, user: @user_attributes
        end

        it_behaves_like 'saves user'
      end

      context 'with CAS enabled' do
        around(:example) do |example|
          env_wrapper('CAS_AUTH' => '1') { example.run }
        end

        before do
          @user_attributes = FactoryGirl.attributes_for(:user)
          post :create, user: @user_attributes
        end

        it_behaves_like 'saves user'
      end
    end

    describe 'GET edit' do
      before { get :edit, id: FactoryGirl.create(:user) }
      it 'should set @can_edit_username to true' do
        expect(assigns(:can_edit_username)).to be_truthy
      end
      it_behaves_like 'page success'
      it { is_expected.to render_template(:edit) }
    end
    describe 'PUT update' do
      context 'with nice params' do
        before do
          @new_attributes = FactoryGirl.attributes_for(:user,
                                                       first_name: 'Lolita')
          put :update, user: @new_attributes, id: user
        end
        it 'should update the user' do
          expect(User.find(user.id)[:first_name]).to eq('Lolita')
        end
        it { is_expected.to set_flash }
      end
      context 'with requirements' do
        before do
          req = FactoryGirl.create :requirement
          @new_attributes = { requirement_ids: ['', req.id.to_s] }
          put :update, user: @new_attributes, id: user
        end
        it 'should update the user' do
          expect(User.find(user.id).requirements.count).to eq(1)
        end
      end
      context 'without nice params' do
        before do
          @bad_attributes = FactoryGirl.attributes_for(:user,
                                                       first_name: 'Lolita',
                                                       last_name: '')
          put :update, user: @bad_attributes, id: user
        end
        it 'should not save' do
          expect(User.find(user.id)[:first_name]).not_to eq('Lolita')
        end
      end
    end
    describe 'PUT find' do
      context 'fake searched id is blank' do
        before do
          request.env['HTTP_REFERER'] = 'where_i_came_from'
          put :find, fake_searched_id: ''
        end
        it { is_expected.to set_flash }
        it { is_expected.to redirect_to('where_i_came_from') }
      end
      context 'searched id is blank' do
        context 'valid id' do
          before do
            FactoryGirl.create(:user, username: 'csw3')
            put :find, fake_searched_id: 'csw3', searched_id: ''
          end
          it 'should assign user correctly' do
            expect(assigns(:user)).to eq(User.where(username: 'csw3').first)
          end
          it do
            is_expected.to\
              redirect_to(manage_reservations_for_user_path(assigns(:user)))
          end
        end
        context 'invalid id' do
          before do
            request.env['HTTP_REFERER'] = 'where_i_came_from'
            put :find, fake_searched_id: 'not_a_real_id3', searched_id: ''
          end
          it { is_expected.to set_flash }
          it { is_expected.to redirect_to('where_i_came_from') }
        end
      end
      context 'searched id is not blank' do
        before do
          put :find, searched_id: user.id, fake_searched_id: 'csw3'
        end
        it 'should assign user' do
          expect(assigns(:user)).to eq(user)
        end
        it do
          is_expected.to\
            redirect_to(manage_reservations_for_user_path(assigns(:user)))
        end
      end
    end
    describe 'PUT ban' do
      before do
        request.env['HTTP_REFERER'] = 'where_i_came_from'
        @user = FactoryGirl.create(:user)
        put :ban, id: @user.id
      end
      it 'should make the user banned' do
        @user.reload
        expect(@user.role).to eq('banned')
        expect(@user.view_mode).to eq('banned')
      end
      it { is_expected.to set_flash }
      it { is_expected.to redirect_to('where_i_came_from') }

      it 'cannot ban self' do
        sign_out :user
        new_admin = FactoryGirl.create :admin
        sign_in new_admin
        put :ban, id: new_admin.id
        new_admin.reload
        expect(new_admin.role).to eq('admin')
        expect(new_admin.view_mode).to eq('admin')
      end
    end
    describe 'PUT unban' do
      before do
        request.env['HTTP_REFERER'] = 'where_i_came_from'
        @user = FactoryGirl.create(:banned)
        put :unban, id: @user.id
      end

      it 'sets user to patron' do
        @user.reload
        expect(@user.role).to eq('normal')
        expect(@user.view_mode).to eq('normal')
      end

      it { is_expected.to set_flash }
      it { is_expected.to redirect_to('where_i_came_from') }
    end
  end
  context 'with checkout person user' do
    before do
      sign_in FactoryGirl.create(:checkout_person)
    end

    describe 'GET new' do
      before { get :new }
      context 'possible netid not provided' do
        it 'should assign @user to a new user' do
          expect(assigns(:user).attributes).to eq(User.new.attributes)
        end
      end
      it 'should assign @can_edit_username to true' do
        expect(assigns(:can_edit_username)).to be_truthy
      end
      it_behaves_like 'page success'
      it { is_expected.to render_template(:new) }
    end

    describe 'GET new when new user registration is disabled' do
      before do
        AppConfig.first.update_attributes(enable_new_users: false)
        get :new
      end

      it { is_expected.to set_flash }
      it 'redirects to homepage' do
        expect(response).to redirect_to(root_url)
      end
    end
  end

  it_behaves_like 'calendarable', User
end
