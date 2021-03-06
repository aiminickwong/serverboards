import React from 'react'
import i18n from 'app/utils/i18n'

function When(props){
  const {section, gotoStep} = props
  const {service_name, trigger_name, params_resume} = props
  return (
    <div className="">
      <div className="top legend">
        <i className="ui big icon power circle"/>
        {i18n("WHEN")}
      </div>
      <div className="ui card">
        <div className={`${section.section=="when:service" ? "active" : ""}`}>
          <a onClick={() => gotoStep("when:service")}>
            <i className="ui cloud icon"/>
            {service_name || i18n("Select related service")}
          </a>
        </div>
        <div className={`${section.section=="when:trigger" ? "active" : ""}`}>
          <a onClick={() => gotoStep("when:trigger")}>
            <i className="ui toggle on icon"/> {trigger_name || i18n("Select a trigger")}
          </a>
        </div>
        <div className={`${section.section=="params" ? "active" : ""}`}>
          <a onClick={() => gotoStep("when:params")}>
            <i className="ui wrench icon"/> {params_resume || i18n("Setup trigger")}
          </a>
        </div>
      </div>
    </div>
  )
}

export default When
