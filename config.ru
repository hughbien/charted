require File.expand_path('lib/boutique', File.dirname(__FILE__))

Boutique.configure(!ENV['BOUTIQUE_CMD'].nil?) do |c|
  c.dev_email     'dev@localhost'
  c.pem_cert_id   'LONGCERTID'
  c.pem_private   File.expand_path('certs/private.pem', File.dirname(__FILE__))
  c.pem_public    File.expand_path('certs/public.pem', File.dirname(__FILE__))
  c.pem_paypal    File.expand_path('certs/paypal.pem', File.dirname(__FILE__))
  c.download_path '/download'
  c.download_dir  File.expand_path('temp', File.dirname(__FILE__))
  c.db_adapter    'sqlite3'
  c.db_host       'localhost'
  c.db_username   'root'
  c.db_password   'secret'
  c.db_database   'db.sqlite3'
  c.pp_email      'paypal_biz@mailinator.com'
  c.pp_url        'http://localhost'
end

Boutique.product('readme') do |p|
  p.name          'README document'
  p.files         File.expand_path('README.md', File.dirname(__FILE__))
  p.price         1.5
  p.return_url    'http://localhost'
  p.support_email 'support@localhost'
end

run Boutique::App if !ENV['BOUTIQUE_CMD']
