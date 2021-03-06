require 'rails_helper'

RSpec.describe Api::V1::RegisterController, type: :controller do
  describe 'GET#captcha' do
    it 'should return captcha_key' do
      get :captcha
      expect(response.header['captcha_key']).not_to be nil
    end
  end

  describe 'GET#send_verify_code' do
    let(:mobile) { '15101520123' }
    it 'should return error when no account' do
      post :send_verify_code
      expect(response).to have_http_status(422)
    end

    it 'should return error when account exist' do
      create(:user, mobile: mobile)
      post :send_verify_code, mobile: mobile, way: 'mobile'
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)['message']).to eq('该账号已被注册')
    end
  end

  describe 'POST#register' do
    include_context 'prepare api signature'
    include_context 'prepare verify code' do
      let(:key) { user_attr[:mobile] }
    end

    let(:user_attr) { attributes_for(:user, :with_mobile) }
    let(:origin_hash) do
      {
        client_id: application.uid,
        user: user_attr,
        timestamp: Time.current.to_i,
        verify_code: @code
      }
    end

    it 'should return error when user exist' do
      create(:user, mobile: user_attr[:mobile])
      post :register, origin_hash.merge(signature: calculate_signature)
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)['message']).to eq('该账号已被注册')
    end

    it 'should verify_signature right' do
      post :register, origin_hash.merge(signature: calculate_signature)
      expect(response).to be_success
      post :register, origin_hash.merge(signature: SecureRandom.hex)
      expect(response).to have_http_status(422)
    end

    it 'should create when user not exist' do
      expect { post :register, origin_hash.merge(signature: calculate_signature) }.to change { User.count }.by(1)
    end

    it 'should create when user not exist' do
      User.create(user_attr)
      expect { post :register, origin_hash.merge(signature: calculate_signature) }.to change { User.count }.by(0)
    end

    it 'should return users token' do
      post :register, origin_hash.merge(signature: calculate_signature)
      expect(JSON.parse(response.body).keys).to eq %w(access_token refresh_token expires_in)
    end
  end
end
