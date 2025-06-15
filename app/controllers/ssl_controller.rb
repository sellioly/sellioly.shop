class SslController < ApplicationController
  include StoreHelper
  before_action :verify_ssl_hook

  public def generate_ssl
    cert = LetsEncrypt::Certificate.find_by(domain: params[:app_domain])
    if cert
      return :json => { :msg => 'This domain Already Certified' }
    end

    cert = LetsEncrypt::Certificate.create(domain: params[:app_domain])
    # alias  `verify && issue`
    if cert.get
      LetsEncrypt::RenewCertificatesJob.perform_later
      render :json => { :msg => 'OK' }
    else
      render :json => { :msg => 'NOT OK' }, status: 400
    end
  end

  public def renew_ssl
    cert = LetsEncrypt::Certificate.find_by(domain: params[:app_domain])
    # alias  `verify && issue`
    if cert
      if cert.renew
        LetsEncrypt::RenewCertificatesJob.perform_later
        render :json => { :msg => 'OK' }
      else
        render :json => { :msg => 'NOT OK' }, status: 400
      end
    else
      generate_ssl
    end
  end

  public def verify_ssl
    cert = LetsEncrypt::Certificate.find_by(domain: params[:app_domain])
    # alias  `verify && issue`
    if cert&.verify
      render :json => { :msg => 'OK' }, status: 200
    else
      render :json => { :msg => 'NOT OK' }, status: 400
    end
  end
end
