<% module_namespacing do -%>
class <%= controller_class_name %>Controller < Api::ApiController

<% unless options[:singleton] -%>
  def index
    @<%= plural_table_name %> = <%= orm_class.all(class_name) %>
    respond_with(@<%= plural_table_name %>)
  end
<% end -%>
  def show
    @<%= singular_table_name %> = <%= orm_class.find(class_name, "params[:id]") %>
    respond_with(@<%= singular_table_name %>)
  end

  def create
    @<%= singular_table_name %> = <%= orm_class.build(class_name, "params[:#{file_name}]") %>
    @<%= orm_instance.save %>
    respond_with(@<%= singular_table_name %>)
  end

  def update
    @<%= singular_table_name %> = <%= orm_class.find(class_name, "params[:id]") %>
    @<%= orm_instance.update("params[:#{file_name}]") %>
    respond_with(@<%= singular_table_name %>)
  end
  def destroy
    @<%= singular_table_name %> = <%= orm_class.find(class_name, "params[:id]") %>
    @<%= orm_instance.destroy %>
    respond_with(@<%= singular_table_name %>)
  end
end
<% end -%>
