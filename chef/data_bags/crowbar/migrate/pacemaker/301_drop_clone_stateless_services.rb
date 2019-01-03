def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("clone_stateless_services")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["clone_stateless_services"] = template_attrs["clone_stateless_services"]
  return attrs, deployment
end
