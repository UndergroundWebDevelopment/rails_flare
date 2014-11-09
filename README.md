# RailsFlare

RailsFlare is a Rails template to assist in creating new API Backend Applications based on
the [Ruby on Rails](http://rubyonrails.org/) framework and (optionaly)
[Ember JS](http://emberjs.com/).

This template is designed and tested with Rails 4.2.0.beta1 

Creates a new Rails App with the following features & Gems
  * Unicorn web server
  * Foreman process manager
    * NOTE: Foreman will be configured to run mysql or postgres,
      along with unicorn.
  * [Pundit](https://github.com/elabs/pundit) authorization.
  * [Reform](https://github.com/apotonick/reform) input forms.
  * [Kaminari](https://github.com/apotonick/kaminari) pagination.
  * [Paranoia](https://github.com/radar/paranoia) safe delete.
  * [ActiveModelSerializers](https://github.com/rails-api/active_model_serializers)
  * UseCase class generators
  * Basic Exceptions, and Exception handling.
  * A customized Rails Scaffold stack, designed for building APIs.
  * RSpec for testing.

The following features are optional:
  * Create a [tmuxinator](https://github.com/tmuxinator/tmuxinator) config file for the new project.
  * Install & configure [Devise](https://github.com/plataformatec/devise)
  * Install & configure [Ember Rails](https://github.com/emberjs/ember-rails)
    * If both Ember & Devise are installed, Ember will be configured to
      authenticate with Devise out of the box.
    * If Ember is installed, [Bootstrap
      SASS](https://github.com/twbs/bootstrap-sass) will also be installed
      and configured.

## Usage:

To create a new site:
`rails_flare new`

After creating a new site, start the app:
`cd <new_site_name>`
`foreman start`

Navigate to `localhost:8080` to view the app.

If you selected to have RailsFlare create a tmuxinator config for you, then
a full development environment can be launched with
`tmuxinator start <app_name>`

## Todo:
  * Add support for postgis geo data (will be optional)

### More Information
More information about application templates can be found
[here](http://guides.rubyonrails.org/rails_application_templates.html).

