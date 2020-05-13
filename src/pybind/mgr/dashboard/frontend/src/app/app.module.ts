import { HttpClientModule, HTTP_INTERCEPTORS } from '@angular/common/http';
import {
  ErrorHandler,
  LOCALE_ID,
  NgModule,
  TRANSLATIONS,
  TRANSLATIONS_FORMAT
} from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';

import { JwtModule } from '@auth0/angular-jwt';
import { I18n } from '@ngx-translate/i18n-polyfill';
import { NgBootstrapFormValidationModule } from 'ng-bootstrap-form-validation';

import { AccordionModule } from 'ngx-bootstrap/accordion';
import { BsDropdownModule } from 'ngx-bootstrap/dropdown';
import { TabsModule } from 'ngx-bootstrap/tabs';
import { ToastrModule } from 'ngx-toastr';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { CephModule } from './ceph/ceph.module';
import { CoreModule } from './core/core.module';
import { ApiInterceptorService } from './shared/services/api-interceptor.service';
import { JsErrorHandler } from './shared/services/js-error-handler.service';
import { SharedModule } from './shared/shared.module';

import { environment } from '../environments/environment';

export function jwtTokenGetter() {
  return localStorage.getItem('access_token');
}

@NgModule({
  declarations: [AppComponent],
  imports: [
    HttpClientModule,
    BrowserModule,
    BrowserAnimationsModule,
    ToastrModule.forRoot({
      positionClass: 'toast-top-right',
      preventDuplicates: true,
      enableHtml: true
    }),
    AppRoutingModule,
    CoreModule,
    SharedModule,
    CephModule,
    AccordionModule.forRoot(),
    BsDropdownModule.forRoot(),
    TabsModule.forRoot(),
    JwtModule.forRoot({
      config: {
        tokenGetter: jwtTokenGetter
      }
    }),
    NgBootstrapFormValidationModule.forRoot()
  ],
  exports: [SharedModule],
  providers: [
    {
      provide: ErrorHandler,
      useClass: JsErrorHandler
    },
    {
      provide: HTTP_INTERCEPTORS,
      useClass: ApiInterceptorService,
      multi: true
    },
    {
      provide: TRANSLATIONS,
      useFactory: (locale: string) => {
        locale = locale || environment.default_lang;
        try {
          return require(`raw-loader!locale/messages.${locale}.xlf`).default;
        } catch (error) {
          return [];
        }
      },
      deps: [LOCALE_ID]
    },
    { provide: TRANSLATIONS_FORMAT, useValue: 'xlf' },
    I18n
  ],
  bootstrap: [AppComponent]
})
export class AppModule {}
